import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../security/password_hasher.dart';
import 'persistence_initializer.dart';

/// Rebuilds a predictable, isolated demo dataset on every Debug-mode start.
/// All owned rows use the `debug_` prefix so user-created development rows are
/// never deleted. This service must only be called through AppEnvironment's
/// compile-time Debug guard.
abstract final class DebugDataSeeder {
  static Future<void> seed() async {
    final manager = PersistenceInitializer.persistenceManager;
    if (manager == null || !manager.isEnabled) return;
    await seedDatabase(manager.sqliteManager.database);
  }

  static Future<void> seedDatabase(Database db) async {
    final now = DateTime.now();

    await db.transaction((txn) async {
      await _removePreviousSeed(txn);
      await _seedUsers(txn, now);
      await _seedRestaurant(txn, now);
      await _seedRawMaterials(txn, now);
      await _seedMenuItemIngredients(txn, now);
      await _seedRestaurantSales(txn, now);
    });
  }

  static Future<void> _removePreviousSeed(Transaction txn) async {
    const childTables = [
      'menu_item_ingredients',
      'stock_movements',
      'payments',
      'order_items',
      'orders',
      'shifts',
      'products',
      'suppliers',
      'categories',
      'activity_logs',
    ];
    for (final table in childTables) {
      try {
        await txn
            .delete(table, where: 'id LIKE ?', whereArgs: ['debug_%']);
      } catch (_) {
        // Table might not exist yet during first run
      }
    }
    await txn.delete('users', where: 'id LIKE ?', whereArgs: ['debug_%']);
  }

  static Future<void> _seedUsers(Transaction txn, DateTime now) async {
    final createdAt = now.toIso8601String();
    await txn.insert('users', {
      'id': 'debug_admin',
      'username': 'debug_admin',
      'display_name': 'مدير التجربة',
      'password_hash': PasswordHasher.hash('admin123'),
      'role': 'manager',
      'permissions': null,
      'is_active': 1,
      'created_at': createdAt,
    });
    await txn.insert('users', {
      'id': 'debug_cashier',
      'username': 'debug_cashier',
      'display_name': 'كاشير التجربة',
      'password_hash': PasswordHasher.hash('cashier123'),
      'role': 'cashier',
      'permissions': [
        'viewDashboard',
        'createOrders',
        'manageTables',
        'viewOrders',
        'updateOrders',
        'processPayments',
      ].join(','),
      'is_active': 1,
      'created_at': createdAt,
      'created_by': 'debug_admin',
    });
  }

  static Future<void> _seedRestaurant(Transaction txn, DateTime now) async {
    final timestamp = now.toIso8601String();
    await txn.insert(
      'restaurant_settings',
      {
        'id': 'restaurant_settings_singleton',
        'restaurant_name': 'GrillPOS Demo',
        'restaurant_address': 'القاهرة - فرع الاختبار',
        'restaurant_phone': '01000000000',
        'restaurant_email': 'demo@grillpos.local',
        'tax_number': 'DEBUG-123456',
        'created_at': timestamp,
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Seeds restaurant raw materials (ingredients) with a supplier.
  static Future<void> _seedRawMaterials(
      Transaction txn, DateTime now) async {
    final timestamp = now.toIso8601String();

    // Supplier
    await txn.insert('suppliers', {
      'id': 'debug_supplier',
      'name': 'موردين أغذية المطعم',
      'contact_name': 'أحمد',
      'phone': '01111111111',
      'email': 'supplier@example.test',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    // Category for raw materials
    await txn.insert('categories', {
      'id': 'debug_cat_meat',
      'name': 'لحوم',
      'color': '#D32F2F',
      'sort_order': 1,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_poultry',
      'name': 'دواجن',
      'color': '#FF9800',
      'sort_order': 2,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_grains',
      'name': 'حبوب ونشويات',
      'color': '#795548',
      'sort_order': 3,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_oils',
      'name': 'زيوت وتوابل',
      'color': '#FFC107',
      'sort_order': 4,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_vegs',
      'name': 'خضروات',
      'color': '#4CAF50',
      'sort_order': 5,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_dairy',
      'name': 'ألبان',
      'color': '#2196F3',
      'sort_order': 6,
    });
    await txn.insert('categories', {
      'id': 'debug_cat_drinks_raw',
      'name': 'مشروبات خام',
      'color': '#00BCD4',
      'sort_order': 7,
    });

    // Raw material products
    final materials = <Map<String, dynamic>>[
      {
        'id': 'debug_mat_beef',
        'name': 'لحم بقري مفروم',
        'cost': 280.0,
        'price': 280.0,
        'stock': 50.0,
        'min_stock': 10.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_meat',
      },
      {
        'id': 'debug_mat_lamb',
        'name': 'لحم ضاني',
        'cost': 450.0,
        'price': 450.0,
        'stock': 30.0,
        'min_stock': 5.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_meat',
      },
      {
        'id': 'debug_mat_chicken',
        'name': 'دجاج كامل',
        'cost': 85.0,
        'price': 85.0,
        'stock': 40.0,
        'min_stock': 10.0,
        'unit': 'حبة',
        'category_id': 'debug_cat_poultry',
      },
      {
        'id': 'debug_mat_rice',
        'name': 'أرز بسمتي',
        'cost': 60.0,
        'price': 60.0,
        'stock': 100.0,
        'min_stock': 20.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_grains',
      },
      {
        'id': 'debug_mat_bread',
        'name': 'خبز بلدي',
        'cost': 1.5,
        'price': 1.5,
        'stock': 200.0,
        'min_stock': 50.0,
        'unit': 'رغيف',
        'category_id': 'debug_cat_grains',
      },
      {
        'id': 'debug_mat_oil',
        'name': 'زيت ذرة',
        'cost': 75.0,
        'price': 75.0,
        'stock': 20.0,
        'min_stock': 5.0,
        'unit': 'لتر',
        'category_id': 'debug_cat_oils',
      },
      {
        'id': 'debug_mat_onion',
        'name': 'بصل',
        'cost': 15.0,
        'price': 15.0,
        'stock': 30.0,
        'min_stock': 5.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_vegs',
      },
      {
        'id': 'debug_mat_tomato',
        'name': 'طماطم',
        'cost': 20.0,
        'price': 20.0,
        'stock': 25.0,
        'min_stock': 5.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_vegs',
      },
      {
        'id': 'debug_mat_potato',
        'name': 'بطاطس',
        'cost': 12.0,
        'price': 12.0,
        'stock': 40.0,
        'min_stock': 10.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_vegs',
      },
      {
        'id': 'debug_mat_tahini',
        'name': 'طحينة خام',
        'cost': 120.0,
        'price': 120.0,
        'stock': 10.0,
        'min_stock': 2.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_oils',
      },
      {
        'id': 'debug_mat_charcoal',
        'name': 'فحم مشويات',
        'cost': 25.0,
        'price': 25.0,
        'stock': 50.0,
        'min_stock': 10.0,
        'unit': 'كيلو',
        'category_id': 'debug_cat_oils',
      },
      {
        'id': 'debug_mat_pepsi',
        'name': 'بيبسي كانز (كرتونة)',
        'cost': 180.0,
        'price': 180.0,
        'stock': 10.0,
        'min_stock': 3.0,
        'unit': 'كرتونة',
        'category_id': 'debug_cat_drinks_raw',
      },
      {
        'id': 'debug_mat_water',
        'name': 'مياه معدنية (شد 12)',
        'cost': 48.0,
        'price': 48.0,
        'stock': 15.0,
        'min_stock': 5.0,
        'unit': 'شد',
        'category_id': 'debug_cat_drinks_raw',
      },
    ];

    for (final mat in materials) {
      await txn.insert('products', {
        ...mat,
        'barcode': mat['id'],
        'min_price': mat['price'],
        'wholesale_price': mat['cost'],
        'supplier_id': 'debug_supplier',
        'warranty_months': 0,
        'track_serials': 0,
        'product_type': 'raw_material',
        'is_active': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      // Opening stock movement
      await txn.insert('stock_movements', {
        'id': 'debug_sm_${mat['id']}',
        'product_id': mat['id'],
        'movement_type': 'opening_stock',
        'quantity': mat['stock'],
        'unit_cost': mat['cost'],
        'notes': 'Debug seed - opening inventory',
        'user_id': 'debug_admin',
        'created_at': timestamp,
      });
    }
  }

  /// Seeds recipe links between generated menu items and raw material products.
  static Future<void> _seedMenuItemIngredients(
      Transaction txn, DateTime now) async {
    final timestamp = now.toIso8601String();

    // Query existing menu items that were seeded by SQLiteManager
    final menuItems = await txn.query('menu_items',
        columns: ['id', 'name', 'category_id'], limit: 50);
    if (menuItems.isEmpty) return;

    // Helper to find a menu item id by partial Arabic name
    String? findItem(String partialAr) {
      for (final item in menuItems) {
        final nameAr = (item['name_ar'] ?? item['name']) as String? ?? '';
        final nameEn = item['name'] as String? ?? '';
        if (nameAr.contains(partialAr) || nameEn.contains(partialAr)) {
          return item['id'] as String;
        }
      }
      return null;
    }

    // Recipe definitions: menu item partial name -> list of (product_id, qty, unit)
    final recipes = <String, List<(String, double, String)>>{
      'كباب مخصوص': [
        ('debug_mat_beef', 1.0, 'كيلو'),
        ('debug_mat_onion', 0.2, 'كيلو'),
        ('debug_mat_charcoal', 0.3, 'كيلو'),
      ],
      'كباب وكفتة': [
        ('debug_mat_beef', 0.5, 'كيلو'),
        ('debug_mat_lamb', 0.5, 'كيلو'),
        ('debug_mat_onion', 0.2, 'كيلو'),
        ('debug_mat_charcoal', 0.3, 'كيلو'),
      ],
      'كفتة مشوية': [
        ('debug_mat_beef', 1.0, 'كيلو'),
        ('debug_mat_onion', 0.3, 'كيلو'),
        ('debug_mat_charcoal', 0.3, 'كيلو'),
      ],
      'فرخة مشوية': [
        ('debug_mat_chicken', 1.0, 'حبة'),
        ('debug_mat_charcoal', 0.5, 'كيلو'),
      ],
      'نصف فرخة مشوية': [
        ('debug_mat_chicken', 0.5, 'حبة'),
        ('debug_mat_charcoal', 0.3, 'كيلو'),
      ],
      'ساندوتش كفتة': [
        ('debug_mat_beef', 0.15, 'كيلو'),
        ('debug_mat_bread', 1.0, 'رغيف'),
        ('debug_mat_onion', 0.05, 'كيلو'),
      ],
      'حواوشي': [
        ('debug_mat_beef', 0.2, 'كيلو'),
        ('debug_mat_bread', 1.0, 'رغيف'),
        ('debug_mat_onion', 0.1, 'كيلو'),
      ],
      'أرز بسمتي': [
        ('debug_mat_rice', 0.3, 'كيلو'),
        ('debug_mat_oil', 0.05, 'لتر'),
      ],
      'سلطة خضراء': [
        ('debug_mat_tomato', 0.15, 'كيلو'),
        ('debug_mat_onion', 0.05, 'كيلو'),
      ],
      'طحينة': [
        ('debug_mat_tahini', 0.1, 'كيلو'),
      ],
      'بطاطس محمرة': [
        ('debug_mat_potato', 0.3, 'كيلو'),
        ('debug_mat_oil', 0.15, 'لتر'),
      ],
      'بيبسي': [
        ('debug_mat_pepsi', 0.04, 'كرتونة'),
      ],
      'مياه معدنية': [
        ('debug_mat_water', 0.08, 'شد'),
      ],
    };

    int counter = 1;
    for (final entry in recipes.entries) {
      final menuItemId = findItem(entry.key);
      if (menuItemId == null) continue;

      for (final (productId, qty, unit) in entry.value) {
        await txn.insert('menu_item_ingredients', {
          'id': 'debug_ingredient_${counter++}',
          'menu_item_id': menuItemId,
          'product_id': productId,
          'quantity_needed': qty,
          'unit': unit,
          'created_at': timestamp,
        });
      }
    }
  }

  static Future<void> _seedRestaurantSales(
    Transaction txn,
    DateTime now,
  ) async {
    final menuItems = await txn.query('menu_items', limit: 6);
    if (menuItems.isEmpty) return;
    await txn.insert('shifts', {
      'id': 'debug_shift_closed',
      'user_id': 'debug_admin',
      'open_time': now.subtract(const Duration(days: 7)).toIso8601String(),
      'close_time':
          now.subtract(const Duration(days: 7, hours: -8)).toIso8601String(),
      'closed_by': 'debug_admin',
      'opening_cash': 500.0,
      'closing_cash': 3450.0,
      'is_open': 0,
    });

    for (var day = 6; day >= 0; day--) {
      final created = now.subtract(Duration(days: day, hours: 2));
      final item = menuItems[day % menuItems.length];
      final price = (item['price'] as num).toDouble();
      final quantity = (day % 3) + 1;
      final subtotal = price * quantity;
      final orderId = 'debug_order_$day';
      await txn.insert('orders', {
        'id': orderId,
        'order_number': 'DBG-${100 + day}',
        'table_id': 'table_${(day % 5) + 1}',
        'order_type': day.isEven ? 'dine_in' : 'takeaway',
        'status': 'completed',
        'subtotal': subtotal,
        'tax': 0.0,
        'discount': 0.0,
        'total_amount': subtotal,
        'payment_status': 'paid',
        'cashier_id': 'debug_cashier',
        'shift_id': 'debug_shift_closed',
        'restaurant_id': 'default',
        'created_at': created.toIso8601String(),
        'updated_at': created.toIso8601String(),
      });
      await txn.insert('order_items', {
        'id': 'debug_order_item_$day',
        'order_id': orderId,
        'menu_item_id': item['id'],
        'item_name': item['name_ar'] ?? item['name'],
        'unit': item['unit'],
        'quantity': quantity.toDouble(),
        'unit_price': price,
        'subtotal': subtotal,
        'status': 'completed',
        'created_at': created.toIso8601String(),
      });
      await txn.insert('payments', {
        'id': 'debug_payment_$day',
        'order_id': orderId,
        'amount': subtotal,
        'method': day.isEven ? 'cash' : 'card',
        'status': 'completed',
        'cashier_id': 'debug_cashier',
        'created_at': created.toIso8601String(),
      });
    }

    final activeItem = menuItems.first;
    final activePrice = (activeItem['price'] as num).toDouble();
    await txn.insert('orders', {
      'id': 'debug_order_active',
      'order_number': 'DBG-LIVE',
      'table_id': 'table_1',
      'order_type': 'dine_in',
      'status': 'preparing',
      'subtotal': activePrice,
      'total_amount': activePrice,
      'payment_status': 'unpaid',
      'cashier_id': 'debug_cashier',
      'restaurant_id': 'default',
      'created_at': now.subtract(const Duration(minutes: 12)).toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await txn.insert('order_items', {
      'id': 'debug_order_item_active',
      'order_id': 'debug_order_active',
      'menu_item_id': activeItem['id'],
      'item_name': activeItem['name_ar'] ?? activeItem['name'],
      'unit': activeItem['unit'],
      'quantity': 1.0,
      'unit_price': activePrice,
      'subtotal': activePrice,
      'status': 'preparing',
      'created_at': now.toIso8601String(),
    });
    await txn.update(
      'restaurant_tables',
      {'status': 'occupied', 'current_order_id': 'debug_order_active'},
      where: 'id = ?',
      whereArgs: ['table_1'],
    );
  }
}
