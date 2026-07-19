import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_models.dart';
import 'package:grill_pos/features/computer_sales/presentation/computer_document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('computer sale PDF contains a valid PDF header', () async {
    final now = DateTime(2026, 7, 18);
    final line = ComputerDocumentLine(
      id: 'line-1',
      documentId: 'sale-1',
      productId: 'product-1',
      productName: 'Business Laptop',
      sku: 'LAP-100',
      quantity: 1,
      unitPrice: 15000,
      unitCost: 10000,
      lineSubtotal: 15000,
      warrantyMonths: 12,
      warrantyExpiry: DateTime(2027, 7, 18),
      returnedQuantity: 0,
      trackSerials: true,
      serials: const [
        AvailableSerial(
          id: 'serial-1',
          productId: 'product-1',
          serialNumber: 'SERIAL-100',
          purchaseCost: 10000,
        ),
      ],
    );
    final document = ComputerDocument(
      id: 'sale-1',
      documentNumber: 'SAL-202607-0001',
      type: ComputerDocumentType.sale,
      status: ComputerDocumentStatus.completed,
      customerId: 'customer-1',
      customerName: 'Test Customer',
      customerPhone: '01000000000',
      subtotal: 15000,
      discountAmount: 0,
      taxRate: 0,
      taxAmount: 0,
      totalAmount: 15000,
      paidAmount: 15000,
      refundedAmount: 0,
      balanceDue: 0,
      paymentStatus: ComputerPaymentStatus.paid,
      createdAt: now,
      updatedAt: now,
      completedAt: now,
      lines: [line],
    );

    final bytes = await ComputerDocumentService.buildPdf(
      document,
      businessName: 'GrillPOS Computer Center',
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
