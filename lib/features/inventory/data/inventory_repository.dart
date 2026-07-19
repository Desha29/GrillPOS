import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/services/persistence_initializer.dart';
import 'inventory_models.dart';

class InventoryRepository {
  InventoryRepository({Database? database}) : _databaseOverride = database;

  static const _uuid = Uuid();
  final Database? _databaseOverride;
  final _changes = StreamController<void>.broadcast();

  Database get _db =>
      _databaseOverride ??
      PersistenceInitializer.persistenceManager!.sqliteManager.database;
  Stream<void> get changes => _changes.stream;

  Future<List<InventoryProduct>> getProducts({
    String search = '',
    bool lowStockOnly = false,
  }) async {
    final where = <String>['p.is_active = 1'];
    final args = <Object?>[];
    final term = search.trim();
    if (term.isNotEmpty) {
      where.add('''(
        p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ? OR
        p.brand LIKE ? OR p.model LIKE ?
      )''');
      args.addAll(List<Object?>.filled(5, '%$term%'));
    }
    if (lowStockOnly) where.add('p.stock <= p.min_stock');

    final rows = await _db.rawQuery('''
      SELECT p.*, c.name AS category_name, s.name AS supplier_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE ${where.join(' AND ')}
      ORDER BY CASE WHEN p.stock <= p.min_stock THEN 0 ELSE 1 END, p.name
    ''', args);
    return rows.map(InventoryProduct.fromMap).toList(growable: false);
  }

  Future<List<Supplier>> getSuppliers() async {
    final rows = await _db.query(
      'suppliers',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    return rows.map(Supplier.fromMap).toList(growable: false);
  }

  Future<InventoryStats> getStats() async {
    final productRows = await _db.rawQuery('''
      SELECT
        COUNT(*) AS product_count,
        SUM(CASE WHEN stock <= min_stock THEN 1 ELSE 0 END) AS low_stock,
        COALESCE(SUM(stock * cost), 0) AS inventory_value
      FROM products WHERE is_active = 1
    ''');
    final serialRows = await _db.rawQuery('''
      SELECT COUNT(*) AS serial_count
      FROM product_serials WHERE status = 'in_stock'
    ''');
    final product = productRows.single;
    return InventoryStats(
      products: (product['product_count'] as num?)?.toInt() ?? 0,
      lowStock: (product['low_stock'] as num?)?.toInt() ?? 0,
      inventoryValue: (product['inventory_value'] as num?)?.toDouble() ?? 0,
      serializedUnits:
          (serialRows.single['serial_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<InventoryProduct> createProduct(
    NewInventoryProductInput input, {
    String? userId,
  }) async {
    _validateProductInput(input);
    final serials = input.serialNumbers
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (input.trackSerials && serials.isEmpty) {
      throw ArgumentError('Add at least one serial number.');
    }
    final now = DateTime.now();
    final productId = _uuid.v4();
    final stock =
        input.trackSerials ? serials.length.toDouble() : input.openingStock;

    await _db.transaction((txn) async {
      final categoryId = await _categoryId(txn, input.categoryName, now);
      await txn.insert('products', {
        'id': productId,
        'sku': _clean(input.sku),
        'barcode': _clean(input.barcode),
        'name': input.name.trim(),
        'brand': _clean(input.brand),
        'model': _clean(input.model),
        'price': input.price,
        'cost': input.cost,
        'stock': stock,
        'min_stock': input.minStock,
        'category_id': categoryId,
        'supplier_id': input.supplierId,
        'warranty_months': input.warrantyMonths,
        'track_serials': input.trackSerials ? 1 : 0,
        'product_type': 'merchandise',
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      for (final serial in serials) {
        await txn.insert('product_serials', {
          'id': _uuid.v4(),
          'product_id': productId,
          'serial_number': serial,
          'status': 'in_stock',
          'purchase_cost': input.cost,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      if (stock > 0) {
        await _insertMovement(
          txn,
          productId: productId,
          type: 'opening_stock',
          quantity: stock,
          unitCost: input.cost,
          notes: 'Opening inventory',
          userId: userId,
          createdAt: now,
        );
      }
    });
    _notify();
    return (await getProducts(search: input.sku ?? input.name)).firstWhere(
      (product) => product.id == productId,
    );
  }

  Future<void> updateProduct(
    InventoryProduct product,
    NewInventoryProductInput input,
  ) async {
    _validateProductInput(input);
    if (input.trackSerials != product.trackSerials) {
      throw StateError(
        'Serial tracking cannot be changed after a product is created.',
      );
    }
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final categoryId = await _categoryId(txn, input.categoryName, now);
      await txn.update(
        'products',
        {
          'sku': _clean(input.sku),
          'barcode': _clean(input.barcode),
          'name': input.name.trim(),
          'brand': _clean(input.brand),
          'model': _clean(input.model),
          'price': input.price,
          'cost': input.cost,
          'min_stock': input.minStock,
          'category_id': categoryId,
          'supplier_id': input.supplierId,
          'warranty_months': input.warrantyMonths,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );
    });
    _notify();
  }

  Future<Supplier> createSupplier(NewSupplierInput input) async {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Supplier name is required.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _db.insert('suppliers', {
      'id': id,
      'name': input.name.trim(),
      'contact_name': _clean(input.contactName),
      'phone': _clean(input.phone),
      'email': _clean(input.email),
      'address': _clean(input.address),
      'tax_number': _clean(input.taxNumber),
      'notes': _clean(input.notes),
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    _notify();
    return (await getSuppliers()).firstWhere((supplier) => supplier.id == id);
  }

  Future<void> adjustStock(
    InventoryProduct product,
    double quantity, {
    required String note,
    String? userId,
  }) async {
    if (product.trackSerials) {
      throw StateError('Use serial-number intake for this product.');
    }
    if (quantity == 0) throw ArgumentError('Quantity cannot be zero.');
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final stockRows = await txn.query(
        'products',
        columns: ['stock'],
        where: 'id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      if (stockRows.isEmpty) throw StateError('Product no longer exists.');
      final currentStock = (stockRows.single['stock'] as num?)?.toDouble() ?? 0;
      final newStock = currentStock + quantity;
      if (newStock < 0) throw StateError('Stock cannot become negative.');
      await txn.update(
        'products',
        {'stock': newStock, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await _insertMovement(
        txn,
        productId: product.id,
        type: 'adjustment',
        quantity: quantity,
        unitCost: product.cost,
        notes: note.trim(),
        userId: userId,
        createdAt: now,
      );
    });
    _notify();
  }

  Future<void> addSerials(
    InventoryProduct product,
    List<String> serialNumbers, {
    String? userId,
  }) async {
    if (!product.trackSerials) {
      throw StateError('This product does not track serial numbers.');
    }
    final serials = serialNumbers
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (serials.isEmpty) throw ArgumentError('No serial numbers supplied.');
    final now = DateTime.now();
    await _db.transaction((txn) async {
      for (final serial in serials) {
        await txn.insert('product_serials', {
          'id': _uuid.v4(),
          'product_id': product.id,
          'serial_number': serial,
          'status': 'in_stock',
          'purchase_cost': product.cost,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      await txn.rawUpdate(
        '''
          UPDATE products
          SET stock = stock + ?, updated_at = ?
          WHERE id = ?
        ''',
        [serials.length, now.toIso8601String(), product.id],
      );
      await _insertMovement(
        txn,
        productId: product.id,
        type: 'serial_intake',
        quantity: serials.length.toDouble(),
        unitCost: product.cost,
        notes: 'Serialized stock intake',
        userId: userId,
        createdAt: now,
      );
    });
    _notify();
  }

  Future<List<ProductSerial>> getSerials(String productId) async {
    final rows = await _db.query(
      'product_serials',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ProductSerial.fromMap).toList(growable: false);
  }

  Future<String?> _categoryId(
    Transaction txn,
    String? categoryName,
    DateTime now,
  ) async {
    final name = _clean(categoryName);
    if (name == null) return null;
    final existing = await txn.query(
      'categories',
      columns: ['id'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final id = _uuid.v4();
    await txn.insert('categories', {'id': id, 'name': name});
    return id;
  }

  Future<void> _insertMovement(
    Transaction txn, {
    required String productId,
    required String type,
    required double quantity,
    required double unitCost,
    required DateTime createdAt,
    String? notes,
    String? userId,
  }) {
    return txn.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': type,
      'quantity': quantity,
      'unit_cost': unitCost,
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    }).then((_) {});
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  void _validateProductInput(NewInventoryProductInput input) {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Product name is required.');
    }
    if (input.price < 0 || input.cost < 0 || input.minStock < 0) {
      throw ArgumentError('Prices and stock levels cannot be negative.');
    }
    if (input.openingStock < 0 || input.warrantyMonths < 0) {
      throw ArgumentError('Stock and warranty values cannot be negative.');
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}
