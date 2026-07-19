import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/services/persistence_initializer.dart';
import 'menu_models.dart';

class MenuRepository {
  static const _uuid = Uuid();

  // ─── Stream for real-time menu updates ─────────────────────────────
  final _menuController = StreamController<void>.broadcast();
  Stream<void> get menuStream => _menuController.stream;

  void _notifyChange() {
    if (!_menuController.isClosed) {
      _menuController.add(null);
    }
  }

  void dispose() {
    _menuController.close();
  }

  Database get _db =>
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  // ─── Categories ────────────────────────────────────────────────────────────

  Future<List<MenuCategory>> getCategories() async {
    final db = _db;
    final rows = await db.query(
      'menu_categories',
      where: 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );

    // If empty, try to seed and query again
    if (rows.isEmpty) {
      await seedDefaultData();
      final retryRows = await db.query(
        'menu_categories',
        where: 'is_active = 1',
        orderBy: 'sort_order ASC, name ASC',
      );
      return retryRows.map(MenuCategory.fromMap).toList();
    }

    return rows.map(MenuCategory.fromMap).toList();
  }

  Future<MenuCategory> createCategory({
    required String name,
    String? nameAr,
    String? icon,
    String? color,
  }) async {
    final db = _db;
    final now = DateTime.now();
    final cat = MenuCategory(
      id: _uuid.v4(),
      name: name,
      nameAr: nameAr,
      icon: icon,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('menu_categories', cat.toMap());
    _notifyChange();
    return cat;
  }

  Future<void> updateCategory(MenuCategory cat) async {
    final db = _db;
    await db.update(
      'menu_categories',
      cat.toMap(),
      where: 'id = ?',
      whereArgs: [cat.id],
    );
    _notifyChange();
  }

  Future<void> deleteCategory(String id) async {
    final db = _db;
    await db.update(
      'menu_categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  // ─── Menu Items ─────────────────────────────────────────────────────────────

  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    final db = _db;
    final rows = await db.query(
      'menu_items',
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(MenuItem.fromMap).toList();
  }

  Future<List<MenuItem>> getAvailableItems({String? categoryId}) async {
    final db = _db;
    final rows = await db.query(
      'menu_items',
      where: categoryId != null
          ? 'is_available = 1 AND category_id = ?'
          : 'is_available = 1',
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(MenuItem.fromMap).toList();
  }

  Future<MenuItem> createItem({
    required String name,
    String? nameAr,
    required String categoryId,
    required double price,
    String? imageUrl,
    String? description,
    String? unit,
    int preparationTime = 10,
  }) async {
    final db = _db;
    final now = DateTime.now();
    final item = MenuItem(
      id: _uuid.v4(),
      name: name,
      nameAr: nameAr,
      categoryId: categoryId,
      price: price,
      imageUrl: imageUrl,
      description: description,
      unit: unit,
      preparationTime: preparationTime,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('menu_items', item.toMap());
    _notifyChange();
    return item;
  }

  Future<void> updateItem(MenuItem item) async {
    final db = _db;
    await db.update(
      'menu_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    _notifyChange();
  }

  Future<void> toggleAvailability(String id, bool available) async {
    final db = _db;
    await db.update(
      'menu_items',
      {
        'is_available': available ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> deleteItem(String id) async {
    final db = _db;
    await db.delete('menu_items', where: 'id = ?', whereArgs: [id]);
    _notifyChange();
  }

  // ─── Seed Default Data (Categories + Items) ─────────────────────────────
  Future<void> seedDefaultData() async {
    await PersistenceInitializer.persistenceManager!.sqliteManager
        .seedMenuDataIfNeeded(_db);
    _notifyChange();
  }
}
