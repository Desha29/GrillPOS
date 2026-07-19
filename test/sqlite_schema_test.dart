import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';
import 'package:grill_pos/features/repairs/data/repair_models.dart';
import 'package:grill_pos/features/repairs/data/repairs_repository.dart';
import 'package:grill_pos/features/inventory/data/inventory_models.dart';
import 'package:grill_pos/features/inventory/data/inventory_repository.dart';

void main() {
  test(
      'database version 14 creates all operational schemas and user permissions',
      () async {
    final directory = await Directory.systemTemp.createTemp('grill_pos_test_');
    final databaseFile =
        File('${directory.path}${Platform.pathSeparator}test.db');
    final manager = SQLiteManager(databasePath: databaseFile.path);

    try {
      await manager.initialize();
      final versionRows =
          await manager.database.rawQuery('PRAGMA user_version');
      expect(versionRows.single['user_version'], 14);

      final tables = await manager.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();

      expect(
          names,
          containsAll(<String>{
            'orders',
            'order_items',
            'customers',
            'repair_tickets',
            'repair_history',
            'suppliers',
            'product_serials',
            'stock_movements',
            'computer_documents',
            'computer_document_items',
            'computer_document_item_serials',
            'computer_payments',
            'computer_returns',
            'computer_return_items',
            'computer_refunds',
          }));

      final userColumns =
          await manager.database.rawQuery('PRAGMA table_info(users)');
      expect(
          userColumns.map((column) => column['name']), contains('permissions'));

      final repairs = RepairsRepository(database: manager.database);
      final ticket = await repairs.createTicket(const NewRepairTicketInput(
        customerName: 'Test Customer',
        customerPhone: '01000000000',
        deviceType: 'Laptop',
        brand: 'Lenovo',
        model: 'ThinkPad',
        serialNumber: 'SERIAL-100',
        reportedIssue: 'Does not power on',
        priority: RepairPriority.urgent,
        estimatedCost: 700,
        deposit: 200,
      ));

      expect(ticket.ticketNumber, startsWith('REP-'));
      expect(await repairs.getTickets(search: 'SERIAL-100'), hasLength(1));

      await repairs.updateTicket(ticket.copyWith(
        status: RepairStatus.ready,
        diagnosis: 'Power circuit repaired',
        finalCost: 750,
        deposit: 250,
      ));
      final stats = await repairs.getStats();
      expect(stats.open, 1);
      expect(stats.ready, 1);
      expect(stats.urgent, 1);
      expect(stats.totalBalanceDue, 500);

      final history = await manager.database.query(
        'repair_history',
        where: 'ticket_id = ?',
        whereArgs: [ticket.id],
      );
      expect(history, hasLength(2));
      repairs.dispose();

      final inventory = InventoryRepository(database: manager.database);
      final supplier = await inventory.createSupplier(const NewSupplierInput(
        name: 'Tech Distributor',
        phone: '01011112222',
      ));
      final product = await inventory.createProduct(NewInventoryProductInput(
        name: 'Business Laptop',
        sku: 'LAP-100',
        brand: 'Lenovo',
        model: 'ThinkPad',
        supplierId: supplier.id,
        price: 15000,
        cost: 10000,
        minStock: 1,
        warrantyMonths: 12,
        trackSerials: true,
        serialNumbers: const ['SER-001', 'SER-002'],
      ));

      expect(product.stock, 2);
      expect(product.trackSerials, isTrue);
      expect(product.supplierName, 'Tech Distributor');
      await inventory.addSerials(product, const ['SER-003']);

      await inventory.updateProduct(
        product,
        NewInventoryProductInput(
          name: 'Business Laptop Gen 2',
          sku: 'LAP-100',
          brand: 'Lenovo',
          model: 'ThinkPad T14',
          supplierId: supplier.id,
          price: 16000,
          cost: 10000,
          minStock: 1,
          warrantyMonths: 24,
          trackSerials: true,
        ),
      );
      final updatedProduct =
          (await inventory.getProducts(search: 'LAP-100')).single;
      expect(updatedProduct.name, 'Business Laptop Gen 2');
      expect(updatedProduct.stock, 3);
      expect(updatedProduct.warrantyMonths, 24);

      final inventoryStats = await inventory.getStats();
      expect(inventoryStats.products, 1);
      expect(inventoryStats.serializedUnits, 3);
      expect(inventoryStats.inventoryValue, 30000);

      final movements = await manager.database.query(
        'stock_movements',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      expect(movements, hasLength(2));
      inventory.dispose();
    } finally {
      await manager.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
