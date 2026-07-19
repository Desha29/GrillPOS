import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/services/persistence_initializer.dart';
import 'table_models.dart';

class TablesException implements Exception {
  const TablesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TablesRepository {
  TablesRepository({Database? database}) : _databaseOverride = database;

  static const _uuid = Uuid();
  final Database? _databaseOverride;
  final _tablesController = StreamController<void>.broadcast();

  Stream<void> get tablesStream => _tablesController.stream;

  Database get _db =>
      _databaseOverride ??
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  Future<List<RestaurantTable>> getTables() async {
    final rows = await _db.query(
      'restaurant_tables',
      orderBy: 'section COLLATE NOCASE, table_number ASC',
    );
    return rows.map(RestaurantTable.fromMap).toList(growable: false);
  }

  Future<RestaurantTable?> getTable(String id) async {
    final rows = await _db.query(
      'restaurant_tables',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RestaurantTable.fromMap(rows.single);
  }

  Future<RestaurantTable> createTable({
    int? tableNumber,
    String? name,
    int capacity = 4,
    String section = 'main',
  }) async {
    final cleanName = _clean(name);
    final cleanSection = _cleanSection(section);
    _validateCapacity(capacity);

    late RestaurantTable created;
    await _db.transaction((txn) async {
      final number = tableNumber ?? await _nextTableNumber(txn);
      if (number <= 0) {
        throw const TablesException('رقم الطاولة يجب أن يكون أكبر من صفر.');
      }
      final duplicate = await txn.query(
        'restaurant_tables',
        columns: const ['id'],
        where: 'table_number = ?',
        whereArgs: [number],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw const TablesException('رقم الطاولة مستخدم بالفعل.');
      }
      created = RestaurantTable(
        id: _uuid.v4(),
        tableNumber: number,
        name: cleanName,
        capacity: capacity,
        section: cleanSection,
      );
      await txn.insert('restaurant_tables', created.toMap());
    });
    _notifyChange();
    return created;
  }

  Future<void> updateTable(RestaurantTable table) async {
    _validateCapacity(table.capacity);
    final existing = await getTable(table.id);
    if (existing == null) {
      throw const TablesException('الطاولة المطلوبة غير موجودة.');
    }
    final changed = await _db.update(
      'restaurant_tables',
      {
        'name': _clean(table.name),
        'capacity': table.capacity,
        'section': _cleanSection(table.section),
      },
      where: 'id = ?',
      whereArgs: [table.id],
    );
    if (changed != 1) {
      throw const TablesException('تعذر حفظ بيانات الطاولة.');
    }
    _notifyChange();
  }

  /// Manual status changes intentionally exclude `occupied`; POS checkout is
  /// the only workflow allowed to occupy a table and attach an active order.
  Future<void> setStatus(String tableId, TableStatus status) async {
    if (status == TableStatus.occupied) {
      throw const TablesException(
        'يتم إشغال الطاولة تلقائياً عند إنشاء طلب من نقطة البيع.',
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'restaurant_tables',
        where: 'id = ?',
        whereArgs: [tableId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const TablesException('الطاولة المطلوبة غير موجودة.');
      }
      final table = RestaurantTable.fromMap(rows.single);
      if (table.currentOrderId != null) {
        throw const TablesException(
          'لا يمكن تغيير حالة طاولة مرتبطة بطلب نشط. أكمل الطلب أو ألغِه أولاً.',
        );
      }
      await txn.update(
        'restaurant_tables',
        {
          'status': status.toDbString(),
          'current_order_id': null,
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );
    });
    _notifyChange();
  }

  Future<void> assignOrder(String tableId, String? orderId) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'restaurant_tables',
        where: 'id = ?',
        whereArgs: [tableId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const TablesException('الطاولة المطلوبة غير موجودة.');
      }
      final table = RestaurantTable.fromMap(rows.single);
      if (orderId != null &&
          table.currentOrderId != null &&
          table.currentOrderId != orderId) {
        throw const TablesException('الطاولة مرتبطة بطلب آخر بالفعل.');
      }
      await txn.update(
        'restaurant_tables',
        {
          'current_order_id': orderId,
          'status': orderId == null
              ? TableStatus.available.toDbString()
              : TableStatus.occupied.toDbString(),
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );
    });
    _notifyChange();
  }

  Future<void> deleteTable(String id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'restaurant_tables',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const TablesException('الطاولة المطلوبة غير موجودة.');
      }
      final table = RestaurantTable.fromMap(rows.single);
      if (table.currentOrderId != null ||
          table.status == TableStatus.occupied) {
        throw const TablesException(
          'لا يمكن حذف طاولة مرتبطة بطلب نشط.',
        );
      }
      final history = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM orders WHERE table_id = ?',
        [id],
      );
      final historyCount = (history.single['count'] as num?)?.toInt() ?? 0;
      if (historyCount > 0) {
        throw const TablesException(
          'لا يمكن حذف طاولة مرتبطة بسجل طلبات سابق. يمكنك إعادة تسميتها أو تغيير قسمها.',
        );
      }
      await txn.delete('restaurant_tables', where: 'id = ?', whereArgs: [id]);
    });
    _notifyChange();
  }

  Future<int> _nextTableNumber(DatabaseExecutor executor) async {
    final rows = await executor.rawQuery(
      'SELECT COALESCE(MAX(table_number), 0) + 1 AS next_number FROM restaurant_tables',
    );
    return (rows.single['next_number'] as num).toInt();
  }

  static void _validateCapacity(int capacity) {
    if (capacity < 1 || capacity > 30) {
      throw const TablesException('سعة الطاولة يجب أن تكون بين 1 و30 مقعداً.');
    }
  }

  static String _cleanSection(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      throw const TablesException('اكتب اسم قسم الصالة.');
    }
    if (clean.length > 40) {
      throw const TablesException('اسم قسم الصالة طويل جداً.');
    }
    return clean;
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    if (clean.length > 50) {
      throw const TablesException('اسم الطاولة طويل جداً.');
    }
    return clean;
  }

  void _notifyChange() {
    if (!_tablesController.isClosed) _tablesController.add(null);
  }

  void dispose() {
    _tablesController.close();
  }
}
