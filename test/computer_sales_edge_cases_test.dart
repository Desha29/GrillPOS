import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_models.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_repository.dart';
import 'package:grill_pos/features/inventory/data/inventory_models.dart';
import 'package:grill_pos/features/inventory/data/inventory_repository.dart';

void main() {
  late _ComputerSalesFixture fixture;

  setUp(() async {
    fixture = await _ComputerSalesFixture.create();
  });

  tearDown(() async {
    await fixture.dispose();
  });

  test(
    'partially paid non-serialized return reduces balance without a refund',
    () async {
      final product = await fixture.createProduct(
        name: 'Returnable Keyboard',
        sku: 'EDGE-RETURN-PARTIAL',
        price: 100,
        cost: 45,
        openingStock: 5,
      );
      final sale = await fixture.createSale(
        product: product,
        quantity: 2,
        unitPrice: 100,
        payments: const [PaymentInput(amount: 50)],
      );

      expect(sale.totalAmount, 200);
      expect(sale.paidAmount, 50);
      expect(sale.balanceDue, 150);
      expect((await fixture.product(product.id)).stock, 3);

      final returned = await fixture.sales.createReturn(
        SaleReturnInput(
          saleId: sale.id,
          createdBy: 'manager',
          reason: 'One unit was not needed',
          lines: [
            ReturnLineInput(
              saleItemId: sale.lines.single.id,
              quantity: 1,
            ),
          ],
        ),
      );

      expect(returned.refundAmount, 100);
      expect(returned.processedRefundAmount, 0);
      expect(returned.refunds, isEmpty);
      expect((await fixture.product(product.id)).stock, 4);

      final updatedSale = await fixture.sales.getDocument(sale.id);
      expect(updatedSale.status, ComputerDocumentStatus.partiallyReturned);
      expect(updatedSale.paymentStatus, ComputerPaymentStatus.partial);
      expect(updatedSale.paidAmount, 50);
      expect(updatedSale.refundedAmount, 0);
      expect(updatedSale.balanceDue, 50);
      expect(updatedSale.lines.single.returnedQuantity, 1);
    },
  );

  test(
    'fully paid partial return requires an exact refund and rolls back if missing',
    () async {
      final product = await fixture.createProduct(
        name: 'Returnable Monitor',
        sku: 'EDGE-RETURN-PAID',
        price: 100,
        cost: 60,
        openingStock: 2,
      );
      final sale = await fixture.createSale(
        product: product,
        quantity: 2,
        unitPrice: 100,
        payments: const [PaymentInput(amount: 200)],
      );
      final returnInput = SaleReturnInput(
        saleId: sale.id,
        createdBy: 'manager',
        lines: [
          ReturnLineInput(
            saleItemId: sale.lines.single.id,
            quantity: 1,
          ),
        ],
      );

      await expectLater(
        fixture.sales.createReturn(returnInput),
        throwsA(
          isA<ComputerSalesException>().having(
            (error) => error.message,
            'message',
            contains('exactly 100.00'),
          ),
        ),
      );

      final unchangedSale = await fixture.sales.getDocument(sale.id);
      expect(unchangedSale.status, ComputerDocumentStatus.completed);
      expect(unchangedSale.refundedAmount, 0);
      expect(unchangedSale.lines.single.returnedQuantity, 0);
      expect(await fixture.sales.listReturns(saleId: sale.id), isEmpty);
      expect((await fixture.product(product.id)).stock, 0);

      final returned = await fixture.sales.createReturn(
        SaleReturnInput(
          saleId: sale.id,
          createdBy: 'manager',
          reason: 'Exact customer refund',
          lines: returnInput.lines,
          refunds: const [
            PaymentInput(
              amount: 100,
              method: ComputerPaymentMethod.card,
              referenceNumber: 'EDGE-REFUND-100',
            ),
          ],
        ),
      );

      expect(returned.refundAmount, 100);
      expect(returned.processedRefundAmount, 100);
      expect(returned.refunds.single.amount, 100);
      expect((await fixture.product(product.id)).stock, 1);

      final updatedSale = await fixture.sales.getDocument(sale.id);
      expect(updatedSale.status, ComputerDocumentStatus.partiallyReturned);
      expect(
        updatedSale.paymentStatus,
        ComputerPaymentStatus.partiallyRefunded,
      );
      expect(updatedSale.refundedAmount, 100);
      expect(updatedSale.balanceDue, 0);
      expect(updatedSale.lines.single.returnedQuantity, 1);
    },
  );

  test('conversion snapshots the current non-serialized inventory cost',
      () async {
    final product = await fixture.createProduct(
      name: 'Costed Router',
      sku: 'EDGE-CURRENT-COST',
      price: 120,
      cost: 40,
      openingStock: 1,
    );
    final customer = await fixture.customer();
    final quotation = await fixture.sales.createDraftQuotation(
      DraftQuotationInput(
        customerId: customer.id,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        createdBy: 'manager',
        lines: [
          QuotationLineInput(
            productId: product.id,
            quantity: 1,
            unitPrice: 120,
          ),
        ],
      ),
    );
    expect(quotation.lines.single.unitCost, 40);

    await fixture.inventory.updateProduct(
      product,
      NewInventoryProductInput(
        name: product.name,
        sku: product.sku,
        barcode: product.barcode,
        brand: product.brand,
        model: product.model,
        price: product.price,
        cost: 70,
        minStock: product.minStock,
        categoryName: product.categoryName,
        supplierId: product.supplierId,
        warrantyMonths: product.warrantyMonths,
        trackSerials: false,
      ),
    );

    final sale = await fixture.sales.convertQuotation(
      quotation.id,
      createdBy: 'manager',
    );
    expect(sale.lines.single.unitCost, 70);

    final movements = await fixture.manager.database.query(
      'stock_movements',
      where: 'product_id = ? AND movement_type = ?',
      whereArgs: [product.id, 'computer_sale'],
    );
    expect(movements, hasLength(1));
    expect((movements.single['unit_cost'] as num).toDouble(), 70);
  });

  test('serialized draft reservations are scoped and safely released',
      () async {
    final product = await fixture.createProduct(
      name: 'Reserved Laptop',
      sku: 'EDGE-SERIAL-RESERVATION',
      price: 900,
      cost: 650,
      trackSerials: true,
      serialNumbers: const ['EDGE-SERIAL-001'],
    );
    final customer = await fixture.customer();
    final serial = (await fixture.sales.getAvailableSerials(product.id)).single;
    final quotation = await fixture.sales.createDraftQuotation(
      DraftQuotationInput(
        customerId: customer.id,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        createdBy: 'manager',
        lines: [
          QuotationLineInput(
            productId: product.id,
            quantity: 1,
            unitPrice: 900,
            serialIds: [serial.id],
          ),
        ],
      ),
    );

    expect(await fixture.sales.getAvailableSerials(product.id), isEmpty);
    expect(
      await fixture.sales.getAvailableSerials(
        product.id,
        forQuotationId: quotation.id,
      ),
      contains(serial),
    );
    await expectLater(
      fixture.sales.createDraftQuotation(
        DraftQuotationInput(
          customerId: customer.id,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          lines: [
            QuotationLineInput(
              productId: product.id,
              quantity: 1,
              unitPrice: 900,
              serialIds: [serial.id],
            ),
          ],
        ),
      ),
      throwsA(isA<ComputerSalesException>()),
    );

    await fixture.sales.cancelQuotation(quotation.id);
    expect(
      await fixture.sales.getAvailableSerials(product.id),
      contains(serial),
    );

    final expiredQuotation = await fixture.sales.createDraftQuotation(
      DraftQuotationInput(
        customerId: customer.id,
        expiryDate: DateTime.now().subtract(const Duration(minutes: 1)),
        createdBy: 'manager',
        lines: [
          QuotationLineInput(
            productId: product.id,
            quantity: 1,
            unitPrice: 900,
            serialIds: [serial.id],
          ),
        ],
      ),
    );
    expect(expiredQuotation.isExpired, isTrue);
    expect(
      await fixture.sales.getAvailableSerials(product.id),
      contains(serial),
    );
    await expectLater(
      fixture.sales.convertQuotation(expiredQuotation.id),
      throwsA(isA<ComputerSalesException>()),
    );
  });

  test('fractional-cent payments store normalized rows and reject overpayment',
      () async {
    final product = await fixture.createProduct(
      name: 'Rounding Adapter',
      sku: 'EDGE-PAYMENT-ROUNDING',
      price: 10,
      cost: 3,
      openingStock: 1,
    );
    var sale = await fixture.createSale(
      product: product,
      quantity: 1,
      unitPrice: 10,
      payments: const [PaymentInput(amount: 1.006)],
    );

    expect(sale.paidAmount, 1.01);
    expect(sale.balanceDue, 8.99);
    expect(sale.payments.single.amount, 1.01);

    await expectLater(
      fixture.sales.addPayment(
        sale.id,
        const PaymentInput(amount: 8.996),
      ),
      throwsA(isA<ComputerSalesException>()),
    );
    sale = await fixture.sales.getDocument(sale.id);
    expect(sale.paidAmount, 1.01);
    expect(sale.balanceDue, 8.99);
    expect(sale.payments, hasLength(1));

    sale = await fixture.sales.addPayment(
      sale.id,
      const PaymentInput(amount: 8.994),
    );
    expect(sale.paidAmount, 10);
    expect(sale.balanceDue, 0);
    expect(sale.paymentStatus, ComputerPaymentStatus.paid);
    expect(
      sale.payments.map((payment) => payment.amount),
      unorderedEquals(const [1.01, 8.99]),
    );

    final storedRows = await fixture.manager.database.query(
      'computer_payments',
      columns: ['amount'],
      where: 'document_id = ?',
      whereArgs: [sale.id],
    );
    expect(
      storedRows.map((row) => (row['amount'] as num).toDouble()),
      unorderedEquals(const [1.01, 8.99]),
    );
  });
}

class _ComputerSalesFixture {
  _ComputerSalesFixture({
    required this.directory,
    required this.manager,
    required this.inventory,
    required this.sales,
  });

  final Directory directory;
  final SQLiteManager manager;
  final InventoryRepository inventory;
  final ComputerSalesRepository sales;
  ComputerCustomer? _customer;

  static Future<_ComputerSalesFixture> create() async {
    final directory =
        await Directory.systemTemp.createTemp('grill_pos_sales_edges_');
    final databaseFile =
        File('${directory.path}${Platform.pathSeparator}test.db');
    final manager = SQLiteManager(databasePath: databaseFile.path);
    await manager.initialize();
    return _ComputerSalesFixture(
      directory: directory,
      manager: manager,
      inventory: InventoryRepository(database: manager.database),
      sales: ComputerSalesRepository(database: manager.database),
    );
  }

  Future<ComputerCustomer> customer() async {
    return _customer ??= await sales.createCustomer(
      const NewComputerCustomerInput(
        name: 'Edge Case Customer',
        phone: '01000000001',
      ),
    );
  }

  Future<InventoryProduct> createProduct({
    required String name,
    required String sku,
    required double price,
    required double cost,
    double openingStock = 0,
    bool trackSerials = false,
    List<String> serialNumbers = const [],
  }) {
    return inventory.createProduct(
      NewInventoryProductInput(
        name: name,
        sku: sku,
        price: price,
        cost: cost,
        openingStock: openingStock,
        minStock: 0,
        trackSerials: trackSerials,
        serialNumbers: serialNumbers,
      ),
      userId: 'manager',
    );
  }

  Future<ComputerDocument> createSale({
    required InventoryProduct product,
    required double quantity,
    required double unitPrice,
    List<PaymentInput> payments = const [],
  }) async {
    final selectedCustomer = await customer();
    final quotation = await sales.createDraftQuotation(
      DraftQuotationInput(
        customerId: selectedCustomer.id,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        createdBy: 'manager',
        lines: [
          QuotationLineInput(
            productId: product.id,
            quantity: quantity,
            unitPrice: unitPrice,
          ),
        ],
      ),
    );
    return sales.convertQuotation(
      quotation.id,
      payments: payments,
      createdBy: 'manager',
    );
  }

  Future<InventoryProduct> product(String id) async {
    return (await inventory.getProducts()).firstWhere(
      (product) => product.id == id,
    );
  }

  Future<void> dispose() async {
    sales.dispose();
    inventory.dispose();
    await manager.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
