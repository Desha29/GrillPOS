import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_models.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_repository.dart';
import 'package:grill_pos/features/inventory/data/inventory_models.dart';
import 'package:grill_pos/features/inventory/data/inventory_repository.dart';

void main() {
  test('quotation sale payment and serialized return restore inventory',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('grill_pos_computer_sale_');
    final databaseFile =
        File('${directory.path}${Platform.pathSeparator}test.db');
    final manager = SQLiteManager(databasePath: databaseFile.path);

    try {
      await manager.initialize();
      final inventory = InventoryRepository(database: manager.database);
      final sales = ComputerSalesRepository(database: manager.database);

      final product = await inventory.createProduct(
        const NewInventoryProductInput(
          name: 'Serialized Laptop',
          sku: 'SALE-LAP-1',
          price: 1500,
          cost: 1000,
          minStock: 0,
          warrantyMonths: 12,
          trackSerials: true,
          serialNumbers: ['SALE-SERIAL-1'],
        ),
      );
      final serial = (await sales.getAvailableSerials(product.id)).single;
      final customer = await sales.createCustomer(
        const NewComputerCustomerInput(
          name: 'Computer Customer',
          phone: '01090000000',
        ),
      );

      final quotation = await sales.createDraftQuotation(
        DraftQuotationInput(
          customerId: customer.id,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          createdBy: 'manager',
          lines: [
            QuotationLineInput(
              productId: product.id,
              quantity: 1,
              unitPrice: 1500,
              warrantyMonths: 12,
              serialIds: [serial.id],
            ),
          ],
        ),
      );
      expect(quotation.status, ComputerDocumentStatus.draft);

      var sale = await sales.convertQuotation(
        quotation.id,
        createdBy: 'manager',
        payments: const [
          PaymentInput(amount: 500, method: ComputerPaymentMethod.cash),
        ],
      );
      expect(sale.status, ComputerDocumentStatus.completed);
      expect(sale.paymentStatus, ComputerPaymentStatus.partial);
      expect(sale.balanceDue, 1000);
      expect(sale.lines.single.serials.single.serialNumber, 'SALE-SERIAL-1');

      final soldProduct =
          (await inventory.getProducts(search: 'SALE-LAP-1')).single;
      expect(soldProduct.stock, 0);
      expect(await sales.getAvailableSerials(product.id), isEmpty);

      sale = await sales.addPayment(
        sale.id,
        const PaymentInput(amount: 1000, method: ComputerPaymentMethod.card),
      );
      expect(sale.paymentStatus, ComputerPaymentStatus.paid);
      expect(sale.balanceDue, 0);

      final returned = await sales.createReturn(
        SaleReturnInput(
          saleId: sale.id,
          createdBy: 'manager',
          reason: 'Customer return',
          lines: [
            ReturnLineInput(
              saleItemId: sale.lines.single.id,
              quantity: 1,
              serialIds: [serial.id],
            ),
          ],
          refunds: const [
            PaymentInput(amount: 1500, method: ComputerPaymentMethod.cash),
          ],
        ),
      );
      expect(returned.refundAmount, 1500);

      final restoredProduct =
          (await inventory.getProducts(search: 'SALE-LAP-1')).single;
      expect(restoredProduct.stock, 1);
      expect(await sales.getAvailableSerials(product.id), hasLength(1));

      final returnedSale = await sales.getDocument(sale.id);
      expect(returnedSale.status, ComputerDocumentStatus.returned);
      expect(returnedSale.paymentStatus, ComputerPaymentStatus.refunded);
      expect(returnedSale.lines.single.returnableQuantity, 0);

      sales.dispose();
      inventory.dispose();
    } finally {
      await manager.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
