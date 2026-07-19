// ignore_for_file: avoid_print

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/file_logger.dart';

/// SQLite database manager with WAL mode and optimizations.
class SQLiteManager {
  final String databasePath;
  Database? _database;

  SQLiteManager({required this.databasePath});

  Future<void> initialize() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    FileLogger.info('Initializing SQLite database at: $databasePath',
        source: 'SQLite');

    _database = await openDatabase(
      databasePath,
      version: 15,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );

    // Robust check for missing columns - MUST be before seeding
    try {
      // Check menu_items
      final menuColumns =
          await _database!.rawQuery('PRAGMA table_info(menu_items)');
      final hasMenuUnit = menuColumns.any((c) => c['name'] == 'unit');
      if (!hasMenuUnit) {
        FileLogger.info('Adding missing unit column to menu_items...',
            source: 'SQLite');
        await _database!.execute('ALTER TABLE menu_items ADD COLUMN unit TEXT');
      }

      // Check order_items
      final orderColumns =
          await _database!.rawQuery('PRAGMA table_info(order_items)');
      final hasOrderUnit = orderColumns.any((c) => c['name'] == 'unit');
      if (!hasOrderUnit) {
        FileLogger.info('Adding missing unit column to order_items...',
            source: 'SQLite');
        await _database!
            .execute('ALTER TABLE order_items ADD COLUMN unit TEXT');
      }

      final userColumns = await _database!.rawQuery('PRAGMA table_info(users)');
      final hasUserPermissions =
          userColumns.any((column) => column['name'] == 'permissions');
      if (!hasUserPermissions) {
        FileLogger.info('Adding missing permissions column to users...',
            source: 'SQLite');
        await _database!
            .execute('ALTER TABLE users ADD COLUMN permissions TEXT');
      }
    } catch (e) {
      FileLogger.error('Error checking/adding missing columns',
          error: e, source: 'SQLite');
    }

    await seedMenuDataIfNeeded(_database!);

    FileLogger.info('SQLite database initialized successfully',
        source: 'SQLite');
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = -64000');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA mmap_size = 30000000000');
    await db.execute('PRAGMA wal_autocheckpoint = 1000');

    FileLogger.debug('SQLite PRAGMAs configured: WAL mode, synchronous=NORMAL',
        source: 'SQLite');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 11) {
      await _createComputerServiceTables(db);
      FileLogger.info('Migration to v11 complete: computer service module',
          source: 'SQLite');
    }
    if (oldVersion < 12) {
      await _createInventoryTables(db);
      FileLogger.info('Migration to v12 complete: inventory foundation',
          source: 'SQLite');
    }
    if (oldVersion < 13) {
      await _createComputerSalesTables(db);
      FileLogger.info(
          'Migration to v13 complete: computer quotations and sales',
          source: 'SQLite');
    }
    if (oldVersion < 14) {
      await _addColumnIfMissing(db, 'users', 'permissions', 'TEXT');
      FileLogger.info(
        'Migration to v14 complete: customizable user permissions',
        source: 'SQLite',
      );
    }
    if (oldVersion < 15) {
      await _createMenuItemIngredientsTable(db);
      await _addColumnIfMissing(db, 'products', 'unit', 'TEXT');
      FileLogger.info(
        'Migration to v15 complete: menu item ingredients and product units',
        source: 'SQLite',
      );
    }

    print('🔄 Migrating database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      print('  ➕ Adding missing columns to sales table...');

      // Add items_count column to sales table
      try {
        await db.execute(
            'ALTER TABLE sales ADD COLUMN items_count INTEGER DEFAULT 0');
        print('    ✅ Added items_count column');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding items_count: $e');
        }
      }

      // Add cashier_name column to sales table
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN cashier_name TEXT');
        print('    ✅ Added cashier_name column');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding cashier_name: $e');
        }
      }

      print('  ➕ Adding missing columns to shifts table...');

      // Add close_time column to shifts table
      try {
        await db.execute('ALTER TABLE shifts ADD COLUMN close_time TEXT');
        print('    ✅ Added close_time column');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding close_time: $e');
        }
      }

      // Add closed_by column to shifts table
      try {
        await db.execute('ALTER TABLE shifts ADD COLUMN closed_by TEXT');
        print('    ✅ Added closed_by column');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding closed_by: $e');
        }
      }

      print('  ✅ Migration complete');
    }

    if (oldVersion < 3) {
      print('  ➕ Adding missing columns to store_settings table...');

      // List of new columns to ensure exist in store_settings
      // store_address, store_phone, store_email, logo_path, tax_number, tax_rate, currency, invoice_prefix
      final newColumns = {
        'store_address': 'TEXT',
        'store_phone': 'TEXT',
        'store_email': 'TEXT',
        'logo_path': 'TEXT',
        'tax_number': 'TEXT',
        'tax_rate': 'REAL DEFAULT 0.0',
        'currency': "TEXT DEFAULT 'EGP'",
        'invoice_prefix': "TEXT DEFAULT 'INV'",
      };

      for (final entry in newColumns.entries) {
        try {
          await db.execute(
              'ALTER TABLE store_settings ADD COLUMN ${entry.key} ${entry.value}');
          print('    ✅ Added ${entry.key} column');
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) {
            print('    ⚠️ Error adding ${entry.key}: $e');
          }
        }
      }

      print('  ✅ Migration to v3 complete');
    }

    if (oldVersion < 4) {
      print('  ➕ Adding activity_logs table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
          id TEXT PRIMARY KEY NOT NULL,
          timestamp TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT NOT NULL,
          user_name TEXT NOT NULL,
          details TEXT
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp DESC)');
      print('  ✅ Migration to v4 complete');
    }

    if (oldVersion < 5) {
      print('  ➕ Adding session_id to activity_logs...');
      try {
        await db
            .execute('ALTER TABLE activity_logs ADD COLUMN session_id TEXT');
        print('    ✅ Added session_id column');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding session_id: $e');
        }
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_session ON activity_logs(session_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_type ON activity_logs(type)');
      print('  ✅ Migration to v5 complete');
    }

    if (oldVersion < 6) {
      print('  ➕ Adding GrillPOS restaurant tables...');

      // Roles table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS roles (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL UNIQUE,
          permissions TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Menu Categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS menu_categories (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          name_ar TEXT,
          icon TEXT,
          color TEXT,
          sort_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          restaurant_id TEXT DEFAULT 'default',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Menu Items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS menu_items (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          name_ar TEXT,
          category_id TEXT NOT NULL,
          price REAL NOT NULL,
          image_url TEXT,
          description TEXT,
          is_available INTEGER DEFAULT 1,
          sort_order INTEGER DEFAULT 0,
          preparation_time INTEGER DEFAULT 10,
          restaurant_id TEXT DEFAULT 'default',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES menu_categories(id)
        )
      ''');

      // Restaurant Tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_tables (
          id TEXT PRIMARY KEY NOT NULL,
          table_number INTEGER NOT NULL,
          name TEXT,
          capacity INTEGER DEFAULT 4,
          status TEXT DEFAULT 'available',
          current_order_id TEXT,
          section TEXT DEFAULT 'main',
          restaurant_id TEXT DEFAULT 'default'
        )
      ''');

      // Orders table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS orders (
          id TEXT PRIMARY KEY NOT NULL,
          order_number TEXT NOT NULL,
          table_id TEXT,
          order_type TEXT NOT NULL DEFAULT 'dine_in',
          status TEXT NOT NULL DEFAULT 'pending',
          subtotal REAL DEFAULT 0.0,
          tax REAL DEFAULT 0.0,
          discount REAL DEFAULT 0.0,
          total_amount REAL NOT NULL DEFAULT 0.0,
          payment_status TEXT DEFAULT 'unpaid',
          notes TEXT,
          cashier_id TEXT,
          waiter_id TEXT,
          shift_id TEXT,
          restaurant_id TEXT DEFAULT 'default',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (table_id) REFERENCES restaurant_tables(id),
          FOREIGN KEY (cashier_id) REFERENCES users(id),
          FOREIGN KEY (shift_id) REFERENCES shifts(id)
        )
      ''');

      // Order Items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_items (
          id TEXT PRIMARY KEY NOT NULL,
          order_id TEXT NOT NULL,
          menu_item_id TEXT NOT NULL,
          item_name TEXT NOT NULL,
          unit TEXT,
          quantity REAL NOT NULL DEFAULT 1.0,
          unit_price REAL NOT NULL,
          subtotal REAL NOT NULL,
          notes TEXT,
          status TEXT DEFAULT 'pending',
          created_at TEXT NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
          FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
        )
      ''');

      // Payments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id TEXT PRIMARY KEY NOT NULL,
          order_id TEXT NOT NULL,
          amount REAL NOT NULL,
          method TEXT NOT NULL DEFAULT 'cash',
          status TEXT DEFAULT 'completed',
          reference_number TEXT,
          cashier_id TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders(id),
          FOREIGN KEY (cashier_id) REFERENCES users(id)
        )
      ''');

      // Daily Reports table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_reports (
          id TEXT PRIMARY KEY NOT NULL,
          report_date TEXT NOT NULL,
          total_revenue REAL DEFAULT 0.0,
          total_orders INTEGER DEFAULT 0,
          total_items_sold INTEGER DEFAULT 0,
          cash_total REAL DEFAULT 0.0,
          card_total REAL DEFAULT 0.0,
          mobile_total REAL DEFAULT 0.0,
          top_items TEXT,
          category_breakdown TEXT,
          shift_id TEXT,
          created_by TEXT,
          restaurant_id TEXT DEFAULT 'default',
          created_at TEXT NOT NULL,
          FOREIGN KEY (shift_id) REFERENCES shifts(id),
          FOREIGN KEY (created_by) REFERENCES users(id)
        )
      ''');

      // Add waiter role to users CHECK constraint by adding column if needed
      try {
        await db.execute('ALTER TABLE users ADD COLUMN role_id TEXT');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding role_id: \$e');
        }
      }

      // Indexes for new tables
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(order_type)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_method ON payments(method)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_restaurant_tables_status ON restaurant_tables(status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_daily_reports_date ON daily_reports(report_date DESC)');

      // Seed default roles
      final now = DateTime.now().toIso8601String();
      await db.execute(
        "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_admin', 'admin', 'all', '$now')",
      );
      await db.execute(
          "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_manager', 'manager', 'manage_menu,manage_tables,manage_orders,view_reports,manage_users', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_cashier', 'cashier', 'create_orders,process_payments,view_menu', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_waiter', 'waiter', 'create_orders,view_menu,view_tables', '\$now')");

      // Seed default menu categories
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_grills', 'Grills', 'مشويات', '🔥', '#FF6F3C', 1, '\$now', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_kebab', 'Kebab', 'كباب', '🥩', '#E84545', 2, '\$now', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_chicken', 'Chicken', 'دجاج', '🍗', '#FF9A3C', 3, '\$now', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_sides', 'Sides', 'مقبلات', '🥗', '#2ECC71', 4, '\$now', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_drinks', 'Drinks', 'مشروبات', '🥤', '#3498DB', 5, '\$now', '\$now')");
      await db.execute(
          "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_desserts', 'Desserts', 'حلويات', '🍰', '#9B59B6', 6, '\$now', '\$now')");

      // Seed default tables (10 tables)
      for (int i = 1; i <= 10; i++) {
        await db.execute(
            "INSERT OR IGNORE INTO restaurant_tables (id, table_number, name, capacity, section) VALUES ('table_\$i', \$i, NULL, 4, 'main')");
      }

      print('  ✅ Migration to v6 (GrillPOS restaurant schema) complete');
    }

    if (oldVersion < 7) {
      print('  ➕ Migrating to v7: Adding unit and real quantities...');

      // Add unit to menu_items
      try {
        await db.execute('ALTER TABLE menu_items ADD COLUMN unit TEXT');
        print('    ✅ Added unit column to menu_items');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print('    ⚠️ Error adding unit to menu_items: $e');
        }
      }

      // SQLite dynamic typing allows REAL in INTEGER columns, but we'll recreate for a clean schema
      try {
        await db.execute('ALTER TABLE order_items RENAME TO order_items_old');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS order_items (
            id TEXT PRIMARY KEY NOT NULL,
            order_id TEXT NOT NULL,
            menu_item_id TEXT NOT NULL,
            item_name TEXT NOT NULL,
            unit TEXT,
            quantity REAL NOT NULL DEFAULT 1.0,
            unit_price REAL NOT NULL,
            subtotal REAL NOT NULL,
            notes TEXT,
            status TEXT DEFAULT 'pending',
            created_at TEXT NOT NULL,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
          )
        ''');
        // Since old table doesn't have unit, we must map columns specifically
        await db.execute(
            'INSERT INTO order_items (id, order_id, menu_item_id, item_name, quantity, unit_price, subtotal, notes, status, created_at) SELECT * FROM order_items_old');
        await db.execute('DROP TABLE order_items_old');
        print('    ✅ Updated order_items quantity to REAL');
      } catch (e) {
        print('    ⚠️ Error migrating order_items: $e');
      }

      print('  ✅ Migration to v7 complete');
    }

    if (oldVersion < 8) {
      print('  ➕ Migrating to v8: Ensuring unit column in order_items...');

      // Try to add unit column if it didn't exist in v7 upgrade
      try {
        await db.execute('ALTER TABLE order_items ADD COLUMN unit TEXT');
        print('    ✅ Added unit column to order_items');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          print(
              '    ⚠️ Note: unit column might already exist in order_items: $e');
        }
      }

      print('  ✅ Migration to v8 complete');
    }

    if (oldVersion < 9) {
      print('  ➕ Migrating to v9: Localizing Table names in Arabic...');
      await db.execute(
          "UPDATE restaurant_tables SET name = NULL WHERE name LIKE 'Table %'");
      print(
          '    ✅ Existing table names reset to NULL (will use localized default)');
      print('  ✅ Migration to v9 complete');
    }

    if (oldVersion < 10) {
      print('  ➕ Migrating to v10: Adding restaurant_settings table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_settings (
          id TEXT PRIMARY KEY NOT NULL,
          restaurant_name TEXT NOT NULL,
          restaurant_address TEXT,
          restaurant_phone TEXT,
          restaurant_email TEXT,
          logo_path TEXT,
          tax_number TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      print('  ✅ Migration to v10 complete');
    }
  }

  Future<void> _createComputerServiceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repair_tickets (
        id TEXT PRIMARY KEY NOT NULL,
        ticket_number TEXT NOT NULL UNIQUE,
        customer_id TEXT NOT NULL,
        device_type TEXT NOT NULL,
        brand TEXT,
        model TEXT,
        serial_number TEXT,
        accessories TEXT,
        reported_issue TEXT NOT NULL,
        diagnosis TEXT,
        technician_name TEXT,
        status TEXT NOT NULL DEFAULT 'received',
        priority TEXT NOT NULL DEFAULT 'normal',
        estimated_cost REAL NOT NULL DEFAULT 0.0,
        final_cost REAL NOT NULL DEFAULT 0.0,
        deposit REAL NOT NULL DEFAULT 0.0,
        due_date TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        CHECK (estimated_cost >= 0),
        CHECK (final_cost >= 0),
        CHECK (deposit >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repair_history (
        id TEXT PRIMARY KEY NOT NULL,
        ticket_id TEXT NOT NULL,
        previous_status TEXT,
        new_status TEXT NOT NULL,
        note TEXT,
        changed_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (ticket_id) REFERENCES repair_tickets(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_repairs_status ON repair_tickets(status, updated_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_repairs_customer ON repair_tickets(customer_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_repairs_serial ON repair_tickets(serial_number)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_repair_history_ticket ON repair_history(ticket_id, created_at DESC)');
  }

  Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        contact_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _addColumnIfMissing(db, 'products', 'sku', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'brand', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'model', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'supplier_id', 'TEXT');
    await _addColumnIfMissing(
        db, 'products', 'warranty_months', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        db, 'products', 'track_serials', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        db, 'products', 'product_type', "TEXT NOT NULL DEFAULT 'merchandise'");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_serials (
        id TEXT PRIMARY KEY NOT NULL,
        product_id TEXT NOT NULL,
        serial_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'in_stock',
        purchase_cost REAL NOT NULL DEFAULT 0.0,
        sale_id TEXT,
        customer_id TEXT,
        warranty_expiry TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        CHECK (purchase_cost >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id TEXT PRIMARY KEY NOT NULL,
        product_id TEXT NOT NULL,
        serial_id TEXT,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        reference_type TEXT,
        reference_id TEXT,
        notes TEXT,
        user_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (serial_id) REFERENCES product_serials(id),
        CHECK (quantity != 0),
        CHECK (unit_cost >= 0)
      )
    ''');

    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku ON products(sku) WHERE sku IS NOT NULL');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_supplier ON products(supplier_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_brand_model ON products(brand, model)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_serials_product ON product_serials(product_id, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
  }

  Future<void> _createComputerSalesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_document_counters (
        series TEXT NOT NULL,
        period TEXT NOT NULL,
        last_number INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (series, period),
        CHECK (last_number >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_documents (
        id TEXT PRIMARY KEY NOT NULL,
        document_number TEXT NOT NULL UNIQUE,
        document_type TEXT NOT NULL,
        status TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        source_quotation_id TEXT,
        converted_sale_id TEXT,
        subtotal REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        tax_rate REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL DEFAULT 0.0,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        refunded_amount REAL NOT NULL DEFAULT 0.0,
        balance_due REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        expiry_date TEXT,
        notes TEXT,
        created_by TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (source_quotation_id) REFERENCES computer_documents(id),
        FOREIGN KEY (converted_sale_id) REFERENCES computer_documents(id),
        CHECK (document_type IN ('quotation', 'sale')),
        CHECK (status IN ('draft', 'converted', 'cancelled', 'completed',
          'partially_returned', 'returned')),
        CHECK (payment_status IN ('unpaid', 'partial', 'paid',
          'partially_refunded', 'refunded')),
        CHECK (subtotal >= 0 AND discount_amount >= 0
          AND discount_amount <= subtotal),
        CHECK (tax_rate >= 0 AND tax_rate <= 100),
        CHECK (tax_amount >= 0 AND total_amount >= 0 AND paid_amount >= 0),
        CHECK (refunded_amount >= 0 AND refunded_amount <= paid_amount),
        CHECK (balance_due >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_document_items (
        id TEXT PRIMARY KEY NOT NULL,
        document_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        line_subtotal REAL NOT NULL,
        warranty_months INTEGER NOT NULL DEFAULT 0,
        warranty_expiry TEXT,
        returned_quantity REAL NOT NULL DEFAULT 0.0,
        track_serials INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (document_id) REFERENCES computer_documents(id)
          ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        CHECK (quantity > 0),
        CHECK (unit_price >= 0 AND unit_cost >= 0 AND line_subtotal >= 0),
        CHECK (warranty_months >= 0),
        CHECK (returned_quantity >= 0 AND returned_quantity <= quantity),
        CHECK (track_serials IN (0, 1))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_document_item_serials (
        document_item_id TEXT NOT NULL,
        serial_id TEXT NOT NULL,
        PRIMARY KEY (document_item_id, serial_id),
        FOREIGN KEY (document_item_id) REFERENCES computer_document_items(id)
          ON DELETE CASCADE,
        FOREIGN KEY (serial_id) REFERENCES product_serials(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_payments (
        id TEXT PRIMARY KEY NOT NULL,
        document_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        reference_number TEXT,
        notes TEXT,
        received_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (document_id) REFERENCES computer_documents(id),
        CHECK (amount > 0 AND amount = ROUND(amount, 2)),
        CHECK (method IN ('cash', 'card', 'bank_transfer', 'mobile_wallet',
          'other'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_returns (
        id TEXT PRIMARY KEY NOT NULL,
        return_number TEXT NOT NULL UNIQUE,
        sale_id TEXT NOT NULL,
        refund_amount REAL NOT NULL DEFAULT 0.0,
        reason TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES computer_documents(id),
        CHECK (refund_amount >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_return_items (
        id TEXT PRIMARY KEY NOT NULL,
        return_id TEXT NOT NULL,
        sale_item_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        serial_id TEXT,
        refund_amount REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (return_id) REFERENCES computer_returns(id)
          ON DELETE CASCADE,
        FOREIGN KEY (sale_item_id) REFERENCES computer_document_items(id),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (serial_id) REFERENCES product_serials(id),
        CHECK (quantity > 0),
        CHECK (refund_amount >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS computer_refunds (
        id TEXT PRIMARY KEY NOT NULL,
        return_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        reference_number TEXT,
        notes TEXT,
        processed_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (return_id) REFERENCES computer_returns(id),
        CHECK (amount > 0 AND amount = ROUND(amount, 2)),
        CHECK (method IN ('cash', 'card', 'bank_transfer', 'mobile_wallet',
          'other'))
      )
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_computer_document_number_immutable
      BEFORE UPDATE OF document_number ON computer_documents
      WHEN OLD.document_number <> NEW.document_number
      BEGIN
        SELECT RAISE(ABORT, 'Document numbers are immutable');
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_computer_return_number_immutable
      BEFORE UPDATE OF return_number ON computer_returns
      WHEN OLD.return_number <> NEW.return_number
      BEGIN
        SELECT RAISE(ABORT, 'Return numbers are immutable');
      END
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_documents_type_status ON computer_documents(document_type, status, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_documents_customer ON computer_documents(customer_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_documents_payment ON computer_documents(payment_status, balance_due)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_document_items_document ON computer_document_items(document_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_document_items_product ON computer_document_items(product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_item_serials_serial ON computer_document_item_serials(serial_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_payments_document ON computer_payments(document_id, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_returns_sale ON computer_returns(sale_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_return_items_sale_item ON computer_return_items(sale_item_id)');
    await db.execute('DROP INDEX IF EXISTS idx_computer_return_serial_once');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_computer_return_serial_per_sale ON computer_return_items(sale_item_id, serial_id) WHERE serial_id IS NOT NULL');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_computer_refunds_return ON computer_refunds(return_id, created_at)');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((item) => item['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Creates the table linking menu items to their raw material ingredients.
  Future<void> _createMenuItemIngredientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_item_ingredients (
        id TEXT PRIMARY KEY NOT NULL,
        menu_item_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity_needed REAL NOT NULL,
        unit TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        CHECK (quantity_needed > 0)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_menu_item_ingredients_menu ON menu_item_ingredients(menu_item_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_menu_item_ingredients_product ON menu_item_ingredients(product_id)');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createComputerServiceTables(db);
    // Store settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_settings (
        id TEXT PRIMARY KEY NOT NULL,
        store_name TEXT NOT NULL,
        store_address TEXT,
        store_phone TEXT,
        store_email TEXT,
        logo_path TEXT,
        tax_number TEXT,
        tax_rate REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'EGP',
        invoice_prefix TEXT DEFAULT 'INV',
        last_invoice_number INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (tax_rate >= 0 AND tax_rate <= 100)
      )
    ''');

    // Restaurant settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_settings (
        id TEXT PRIMARY KEY NOT NULL,
        restaurant_name TEXT NOT NULL,
        restaurant_address TEXT,
        restaurant_phone TEXT,
        restaurant_email TEXT,
        logo_path TEXT,
        tax_number TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Activity Logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id TEXT PRIMARY KEY NOT NULL,
        session_id TEXT,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        user_name TEXT NOT NULL,
        details TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_logs_session ON activity_logs(session_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_logs_type ON activity_logs(type)');

    // Categories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY NOT NULL,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        min_price REAL DEFAULT 0.0,
        wholesale_price REAL DEFAULT 0.0,
        cost REAL DEFAULT 0.0,
        stock REAL DEFAULT 0.0,
        min_stock REAL DEFAULT 0.0,
        unit TEXT,
        category_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await _createInventoryTables(db);
    await _createComputerSalesTables(db);
    await _createMenuItemIngredientsTable(db);

    // Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'cashier',
          permissions TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        created_by TEXT,
        last_login TEXT,
        CHECK (role IN ('admin', 'manager', 'cashier')),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');

    // Shifts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        open_time TEXT NOT NULL,
        close_time TEXT,
        closed_by TEXT,
        opening_cash REAL DEFAULT 0.0,
        closing_cash REAL DEFAULT 0.0,
        is_open INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY NOT NULL,
        total REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        user_id TEXT,
        cashier_name TEXT,
        items_count INTEGER DEFAULT 0,
        is_refund INTEGER NOT NULL DEFAULT 0,
        original_sale_id TEXT,
        shift_id TEXT,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'cash',
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (original_sale_id) REFERENCES sales(id),
        FOREIGN KEY (shift_id) REFERENCES shifts(id)
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_barcode TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        wholesale_price REAL DEFAULT 0.0,
        subtotal REAL NOT NULL,
        refunded_quantity REAL DEFAULT 0.0,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        CHECK (quantity > 0),
        CHECK (price >= 0),
        CHECK (refunded_quantity >= 0),
        CHECK (refunded_quantity <= quantity)
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shifts_user_id ON shifts(user_id)');

    // Additional performance indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_shift_date ON sales(shift_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_is_refund ON sales(is_refund, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active, category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_low_stock ON products(stock, min_stock) WHERE stock < min_stock');

    FileLogger.info('Database indexes created', source: 'SQLite');

    // Insert default settings
    await db.execute('''
      INSERT INTO store_settings (
        id, store_name, store_address, store_phone,
        currency, invoice_prefix, last_invoice_number,
        created_at, updated_at
      ) VALUES (
        'store_settings_singleton', 'GrillPOS Restaurant', '', '',
        'EGP', 'INV', 0,
        '${DateTime.now().toIso8601String()}',
        '${DateTime.now().toIso8601String()}'
      )
    ''');

    // ─── GrillPOS Restaurant Tables ────────────────────────────────────

    // Roles table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL UNIQUE,
        permissions TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Menu Categories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_categories (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        name_ar TEXT,
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        restaurant_id TEXT DEFAULT 'default',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Menu Items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_items (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        name_ar TEXT,
        category_id TEXT NOT NULL,
        price REAL NOT NULL,
        unit TEXT,
        image_url TEXT,
        description TEXT,
        is_available INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        preparation_time INTEGER DEFAULT 10,
        restaurant_id TEXT DEFAULT 'default',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES menu_categories(id)
      )
    ''');

    // Restaurant Tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id TEXT PRIMARY KEY NOT NULL,
        table_number INTEGER NOT NULL,
        name TEXT,
        capacity INTEGER DEFAULT 4,
        status TEXT DEFAULT 'available',
        current_order_id TEXT,
        section TEXT DEFAULT 'main',
        restaurant_id TEXT DEFAULT 'default'
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY NOT NULL,
        order_number TEXT NOT NULL,
        table_id TEXT,
        order_type TEXT NOT NULL DEFAULT 'dine_in',
        status TEXT NOT NULL DEFAULT 'pending',
        subtotal REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        total_amount REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT DEFAULT 'unpaid',
        notes TEXT,
        cashier_id TEXT,
        waiter_id TEXT,
        shift_id TEXT,
        restaurant_id TEXT DEFAULT 'default',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES restaurant_tables(id),
        FOREIGN KEY (cashier_id) REFERENCES users(id),
        FOREIGN KEY (shift_id) REFERENCES shifts(id)
      )
    ''');

    // Order Items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id TEXT PRIMARY KEY NOT NULL,
        order_id TEXT NOT NULL,
        menu_item_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        unit TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY NOT NULL,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        reference_number TEXT,
        cashier_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id),
        FOREIGN KEY (cashier_id) REFERENCES users(id)
      )
    ''');

    // Daily Reports table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_reports (
        id TEXT PRIMARY KEY NOT NULL,
        report_date TEXT NOT NULL,
        total_revenue REAL DEFAULT 0.0,
        total_orders INTEGER DEFAULT 0,
        total_items_sold INTEGER DEFAULT 0,
        cash_total REAL DEFAULT 0.0,
        card_total REAL DEFAULT 0.0,
        mobile_total REAL DEFAULT 0.0,
        top_items TEXT,
        category_breakdown TEXT,
        shift_id TEXT,
        created_by TEXT,
        restaurant_id TEXT DEFAULT 'default',
        created_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');

    // Restaurant indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(order_type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_method ON payments(method)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_restaurant_tables_status ON restaurant_tables(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_reports_date ON daily_reports(report_date DESC)');

    // Seed default roles
    final now = DateTime.now().toIso8601String();
    await db.execute(
        "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_admin', 'admin', 'all', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_manager', 'manager', 'manage_menu,manage_tables,manage_orders,view_reports,manage_users', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_cashier', 'cashier', 'create_orders,process_payments,view_menu', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO roles (id, name, permissions, created_at) VALUES ('role_waiter', 'waiter', 'create_orders,view_menu,view_tables', '$now')");

    // Seed default menu categories
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_grills', 'Grills', '\u0645\u0634\u0648\u064a\u0627\u062a', '\ud83d\udd25', '#FF6F3C', 1, '$now', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_kebab', 'Kebab', '\u0643\u0628\u0627\u0628', '\ud83e\udd69', '#E84545', 2, '$now', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_chicken', 'Chicken', '\u062f\u062c\u0627\u062c', '\ud83c\udf57', '#FF9A3C', 3, '$now', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_sides', 'Sides', '\u0645\u0642\u0628\u0644\u0627\u062a', '\ud83e\udd57', '#2ECC71', 4, '$now', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_drinks', 'Drinks', '\u0645\u0634\u0631\u0648\u0628\u0627\u062a', '\ud83e\udd64', '#3498DB', 5, '$now', '$now')");
    await db.execute(
        "INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) VALUES ('cat_desserts', 'Desserts', '\u062d\u0644\u0648\u064a\u0627\u062a', '\ud83c\udf70', '#9B59B6', 6, '$now', '$now')");

    // Seed default tables
    for (int i = 1; i <= 10; i++) {
      await db.execute(
          "INSERT OR IGNORE INTO restaurant_tables (id, table_number, name, capacity, section) VALUES ('table_$i', $i, 'Table $i', 4, 'main')");
    }
  }

  Future<void> seedMenuDataIfNeeded(Database db) async {
    final now = DateTime.now().toIso8601String();

    final categories = [
      {
        'id': 'cat_grills',
        'name': 'Grills',
        'ar': 'مشويات',
        'icon': '🔥',
        'color': '#FF6F3C',
        'sort': 1
      },
      {
        'id': 'cat_kebab',
        'name': 'Kebab',
        'ar': 'كباب',
        'icon': '🥩',
        'color': '#E84545',
        'sort': 2
      },
      {
        'id': 'cat_chicken',
        'name': 'Chicken',
        'ar': 'دجاج',
        'icon': '🍗',
        'color': '#FF9A3C',
        'sort': 3
      },
      {
        'id': 'cat_sandwiches',
        'name': 'Sandwiches',
        'ar': 'ساندوتشات',
        'icon': '🥪',
        'color': '#FFC107',
        'sort': 4
      },
      {
        'id': 'cat_sides',
        'name': 'Sides',
        'ar': 'مقبلات',
        'icon': '🥗',
        'color': '#2ECC71',
        'sort': 5
      },
      {
        'id': 'cat_kofta',
        'name': 'Kofta',
        'ar': 'كفتة',
        'icon': '🍢',
        'color': '#8B4513',
        'sort': 6
      },
      {
        'id': 'cat_meals',
        'name': 'Meals',
        'ar': 'وجبات',
        'icon': '🍽️',
        'color': '#9B59B6',
        'sort': 7
      },
      {
        'id': 'cat_desserts',
        'name': 'Desserts',
        'ar': 'حلويات',
        'icon': '🍰',
        'color': '#E91E63',
        'sort': 8
      },
      {
        'id': 'cat_drinks',
        'name': 'Drinks',
        'ar': 'مشروبات',
        'icon': '🥤',
        'color': '#3498DB',
        'sort': 9
      },
    ];

    for (final cat in categories) {
      await db.execute('''
        INSERT OR IGNORE INTO menu_categories (id, name, name_ar, icon, color, sort_order, created_at, updated_at) 
        VALUES ('${cat['id']}', '${cat['name']}', '${cat['ar']}', '${cat['icon']}', '${cat['color']}', ${cat['sort']}, '$now', '$now')
      ''');
    }

    final countList = await db.rawQuery(
        'SELECT COUNT(*) as c FROM menu_items WHERE id LIKE "item_gen_%"');
    final count = countList.isNotEmpty ? (countList.first['c'] as int?) : 0;
    if (count != null && count > 10) return;

    final itemsMap = {
      'cat_grills': [
        {
          'en': 'Mixed Grill (1kg)',
          'ar': 'مشويات مشكلة',
          'p': 550.0,
          'u': 'كيلو'
        },
        {'en': 'Grilled Ribs (1kg)', 'ar': 'ريش ضاني', 'p': 750.0, 'u': 'كيلو'},
        {'en': 'Grilled Liver', 'ar': 'كبدة مشوية', 'p': 220.0, 'u': 'طلب'},
        {'en': 'Tarb', 'ar': 'طرب مشوي', 'p': 320.0, 'u': 'كيلو'},
        {
          'en': 'Mixed Grill Plate',
          'ar': 'طبق مشكل جريل',
          'p': 180.0,
          'u': 'طبق'
        },
      ],
      'cat_kebab': [
        {'en': 'Kebab (1kg)', 'ar': 'كباب مخصوص', 'p': 700.0, 'u': 'كيلو'},
        {
          'en': 'Kebab & Kofta (1kg)',
          'ar': 'كباب وكفتة',
          'p': 650.0,
          'u': 'كيلو'
        },
        {'en': 'Shish Kebab', 'ar': 'شيش كباب', 'p': 450.0, 'u': 'كيلو'},
      ],
      'cat_kofta': [
        {'en': 'Kofta (1kg)', 'ar': 'كفتة مشوية', 'p': 500.0, 'u': 'كيلو'},
        {'en': 'Lamb Kofta', 'ar': 'كفتة ضاني', 'p': 550.0, 'u': 'كيلو'},
        {'en': 'Kofta Tray', 'ar': 'صينية كفتة', 'p': 140.0, 'u': 'كيلو'},
      ],
      'cat_chicken': [
        {'en': 'Grilled Chicken', 'ar': 'فرخة مشوية', 'p': 180.0, 'u': 'فرخة'},
        {
          'en': 'Half Chicken',
          'ar': 'نصف فرخة مشوية',
          'p': 95.0,
          'u': 'نصف فرخة'
        },
        {'en': 'Shish Tawook', 'ar': 'شيش طاووق', 'p': 400.0, 'u': 'كيلو'},
        {
          'en': 'Stuffed Chicken',
          'ar': 'فرخة محشية أرز',
          'p': 220.0,
          'u': 'فرخة'
        },
      ],
      'cat_sandwiches': [
        {'en': 'Kofta Sandwich', 'ar': 'ساندوتش كفتة', 'p': 45.0, 'u': 'رغيف'},
        {'en': 'Tarb Sandwich', 'ar': 'ساندوتش طرب', 'p': 55.0, 'u': 'رغيف'},
        {'en': 'Shish Sandwich', 'ar': 'ساندوتش شيش', 'p': 50.0, 'u': 'رغيف'},
        {'en': 'Hawawshi', 'ar': 'حواوشي مخصوص', 'p': 60.0, 'u': 'رغيف'},
        {'en': 'Kebab Sandwich', 'ar': 'ساندوتش كباب', 'p': 75.0, 'u': 'رغيف'},
      ],
      'cat_sides': [
        {'en': 'Basmati Rice', 'ar': 'أرز بسمتي', 'p': 35.0, 'u': 'طبق'},
        {'en': 'Green Salad', 'ar': 'سلطة خضراء', 'p': 15.0, 'u': 'علبة'},
        {'en': 'Tahini', 'ar': 'طحينة', 'p': 15.0, 'u': 'علبة'},
        {'en': 'Baba Ghanoush', 'ar': 'بابا غنوج', 'p': 20.0, 'u': 'علبة'},
        {'en': 'French Fries', 'ar': 'بطاطس محمرة', 'p': 30.0, 'u': 'طلب'},
        {'en': 'Mombar', 'ar': 'ممبار مخصوص', 'p': 60.0, 'u': 'طلب'},
        {
          'en': 'Sambousek (6pcs)',
          'ar': 'سمبوسك (6 قطع)',
          'p': 45.0,
          'u': 'طبق'
        },
      ],
      'cat_meals': [
        {
          'en': 'Individual Meal A',
          'ar': 'وجبة كباب وكفتة فردية',
          'p': 145.0,
          'u': 'وجبة'
        },
        {
          'en': 'Mix Grill Meal',
          'ar': 'وجبة ميكس جريل',
          'p': 175.0,
          'u': 'وجبة'
        },
        {'en': 'Chicken Meal', 'ar': 'وجبة نصف فرخة', 'p': 120.0, 'u': 'وجبة'},
        {
          'en': 'Family Meal (4 People)',
          'ar': 'وجبة عائلية (4 أفراد)',
          'p': 850.0,
          'u': 'وجبة'
        },
      ],
      'cat_drinks': [
        {'en': 'Pepsi', 'ar': 'بيبسي كولا', 'p': 18.0, 'u': 'كانز'},
        {
          'en': 'Water (Small)',
          'ar': 'مياه معدنية صغيرة',
          'p': 10.0,
          'u': 'زجاجة'
        },
        {'en': 'Orange Juice', 'ar': 'عصير برتقال فرش', 'p': 35.0, 'u': 'كوب'},
        {'en': 'Fresh Ayran', 'ar': 'عيران طازج', 'p': 25.0, 'u': 'كوب'},
      ],
      'cat_desserts': [
        {'en': 'Om Ali', 'ar': 'أم علي بالمكسرات', 'p': 45.0, 'u': 'طاجن'},
        {'en': 'Rice Pudding', 'ar': 'أرز بلبن فخار', 'p': 30.0, 'u': 'طبق'},
        {
          'en': 'Kunafa w/ Cream',
          'ar': 'كنافة بالكريمة',
          'p': 50.0,
          'u': 'قطعة'
        },
      ],
    };

    int idCounter = 1;
    for (final entry in itemsMap.entries) {
      final categoryId = entry.key;
      final items = entry.value;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final id = 'item_gen_${idCounter++}';
        await db.execute('''
          INSERT OR IGNORE INTO menu_items 
          (id, name, name_ar, category_id, price, unit, is_available, sort_order, created_at, updated_at) 
          VALUES ('$id', '${item['en']}', '${item['ar']}', '$categoryId', ${item['p']}, '${item['u']}', 1, $i, '$now', '$now')
        ''');
      }
    }
  }

  Database get database {
    if (_database == null) {
      throw StateError('Database not initialized');
    }
    return _database!;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = await database.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    print(
        '🔍 SQL SELECT from $table | Count: ${results.length} | Time: ${stopwatch.elapsedMilliseconds}ms');
    // Optional: verbose log for small results?
    // if (results.length < 5) print('   Results: $results');
    return results;
  }

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    print('📝 SQL INSERT into $table | Data: $values');
    return database.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    print(
        '📝 SQL UPDATE $table | Where: $where | Args: $whereArgs | Data: $values');
    return database.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    print('🗑️ SQL DELETE from $table | Where: $where | Args: $whereArgs');
    return database.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    print('⚙️ SQL EXECUTE: $sql | Args: $arguments');
    await database.execute(sql, arguments);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    print('🔄 SQL TRANSACTION START');
    try {
      final result = await database.transaction(action);
      print('✅ SQL TRANSACTION COMMIT');
      return result;
    } catch (e) {
      print('❌ SQL TRANSACTION ROLLBACK: $e');
      rethrow;
    }
  }

  Future<bool> checkIntegrity() async {
    final result = await database.rawQuery('PRAGMA integrity_check');
    return result.isNotEmpty && result.first.values.first == 'ok';
  }

  Future<void> checkpoint() async {
    await database.execute('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> close() async {
    await checkpoint();
    await _database?.close();
    _database = null;
  }
}
