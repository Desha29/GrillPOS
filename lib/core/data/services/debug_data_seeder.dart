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
      await _seedInventory(txn, now);
      await _seedRepairs(txn, now);
      await _seedRestaurantSales(txn, now);
      await _seedComputerSales(txn, now);
    });
  }

  static Future<void> _removePreviousSeed(Transaction txn) async {
    const childTables = [
      'computer_payments',
      'computer_document_item_serials',
      'computer_document_items',
      'computer_documents',
      'repair_history',
      'repair_tickets',
      'stock_movements',
      'product_serials',
      'payments',
      'order_items',
      'orders',
      'shifts',
      'products',
      'suppliers',
      'customers',
      'categories',
      'activity_logs',
    ];
    for (final table in childTables) {
      final idColumn =
          table == 'computer_document_item_serials' ? 'document_item_id' : 'id';
      await txn
          .delete(table, where: '$idColumn LIKE ?', whereArgs: ['debug_%']);
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
        'manageRepairs',
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

  static Future<void> _seedInventory(Transaction txn, DateTime now) async {
    final timestamp = now.toIso8601String();
    await txn.insert('categories', {
      'id': 'debug_cat_parts',
      'name': 'Computer Parts',
      'color': '#60A5FA',
      'sort_order': 1,
    });
    await txn.insert('suppliers', {
      'id': 'debug_supplier',
      'name': 'مورد الاختبار',
      'contact_name': 'أحمد',
      'phone': '01111111111',
      'email': 'supplier@example.test',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    final products = [
      (
        'debug_product_ssd',
        'SSD 1TB NVMe',
        'SSD-DEMO-1',
        2850.0,
        2100.0,
        8.0,
        2.0,
        1
      ),
      (
        'debug_product_ram',
        'RAM 16GB DDR4',
        'RAM-DEMO-16',
        1450.0,
        980.0,
        3.0,
        4.0,
        0
      ),
      (
        'debug_product_mouse',
        'Gaming Mouse',
        'MOUSE-DEMO',
        650.0,
        390.0,
        14.0,
        3.0,
        0
      ),
    ];
    for (final product in products) {
      await txn.insert('products', {
        'id': product.$1,
        'barcode': product.$1,
        'name': product.$2,
        'sku': product.$3,
        'brand': 'DemoTech',
        'price': product.$4,
        'min_price': product.$4 * .9,
        'wholesale_price': product.$4 * .85,
        'cost': product.$5,
        'stock': product.$6,
        'min_stock': product.$7,
        'category_id': 'debug_cat_parts',
        'supplier_id': 'debug_supplier',
        'warranty_months': 12,
        'track_serials': product.$8,
        'product_type': 'merchandise',
        'is_active': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
    }
    await txn.insert('product_serials', {
      'id': 'debug_serial_ssd_1',
      'product_id': 'debug_product_ssd',
      'serial_number': 'DEMO-SSD-0001',
      'status': 'in_stock',
      'purchase_cost': 2100.0,
      'warranty_expiry': now.add(const Duration(days: 365)).toIso8601String(),
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await txn.insert('stock_movements', {
      'id': 'debug_stock_opening',
      'product_id': 'debug_product_ssd',
      'serial_id': 'debug_serial_ssd_1',
      'movement_type': 'opening_stock',
      'quantity': 1.0,
      'unit_cost': 2100.0,
      'notes': 'Debug seed data',
      'user_id': 'debug_admin',
      'created_at': timestamp,
    });
  }

  static Future<void> _seedRepairs(Transaction txn, DateTime now) async {
    final timestamp = now.toIso8601String();
    await txn.insert('customers', {
      'id': 'debug_customer_walkin',
      'name': 'عميل تجريبي',
      'phone': '01222222222',
      'email': 'customer@example.test',
      'address': 'القاهرة',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    final tickets = [
      (
        'debug_repair_1',
        'DBG-R-001',
        'Laptop',
        'Dell',
        'Latitude 5420',
        'in_progress',
        'urgent',
        'الجهاز لا يعمل',
        1200.0,
        400.0
      ),
      (
        'debug_repair_2',
        'DBG-R-002',
        'Desktop',
        'HP',
        'ProDesk',
        'ready',
        'normal',
        'تغيير مزود الطاقة',
        850.0,
        850.0
      ),
    ];
    for (final ticket in tickets) {
      await txn.insert('repair_tickets', {
        'id': ticket.$1,
        'ticket_number': ticket.$2,
        'customer_id': 'debug_customer_walkin',
        'device_type': ticket.$3,
        'brand': ticket.$4,
        'model': ticket.$5,
        'reported_issue': ticket.$8,
        'technician_name': 'فني التجربة',
        'status': ticket.$6,
        'priority': ticket.$7,
        'estimated_cost': ticket.$9,
        'final_cost': ticket.$6 == 'ready' ? ticket.$9 : 0.0,
        'deposit': ticket.$10,
        'due_date': now.add(const Duration(days: 2)).toIso8601String(),
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'updated_at': timestamp,
      });
    }
    await txn.insert('repair_history', {
      'id': 'debug_repair_history_1',
      'ticket_id': 'debug_repair_1',
      'previous_status': 'received',
      'new_status': 'in_progress',
      'note': 'تم بدء الفحص الفني',
      'changed_by': 'debug_admin',
      'created_at': timestamp,
    });
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

  static Future<void> _seedComputerSales(
    Transaction txn,
    DateTime now,
  ) async {
    final timestamp = now.toIso8601String();
    await txn.insert('computer_documents', {
      'id': 'debug_computer_sale',
      'document_number': 'DBG-SALE-001',
      'document_type': 'sale',
      'status': 'completed',
      'customer_id': 'debug_customer_walkin',
      'subtotal': 2850.0,
      'discount_amount': 0.0,
      'tax_rate': 0.0,
      'tax_amount': 0.0,
      'total_amount': 2850.0,
      'paid_amount': 2850.0,
      'refunded_amount': 0.0,
      'balance_due': 0.0,
      'payment_status': 'paid',
      'notes': 'Debug seed sale',
      'created_by': 'debug_admin',
      'completed_at': timestamp,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await txn.insert('computer_document_items', {
      'id': 'debug_computer_item',
      'document_id': 'debug_computer_sale',
      'product_id': 'debug_product_ssd',
      'product_name': 'SSD 1TB NVMe',
      'sku': 'SSD-DEMO-1',
      'quantity': 1.0,
      'unit_price': 2850.0,
      'unit_cost': 2100.0,
      'line_subtotal': 2850.0,
      'warranty_months': 12,
      'returned_quantity': 0.0,
      'track_serials': 1,
      'created_at': timestamp,
    });
    await txn.insert('computer_payments', {
      'id': 'debug_computer_payment',
      'document_id': 'debug_computer_sale',
      'amount': 2850.0,
      'method': 'cash',
      'received_by': 'debug_admin',
      'created_at': timestamp,
    });
  }
}
