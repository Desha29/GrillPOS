import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_models.dart';

void main() {
  test('computer sales enum values round-trip database labels', () {
    expect(
      ComputerDocumentStatusX.fromDb(
        ComputerDocumentStatus.partiallyReturned.dbValue,
      ),
      ComputerDocumentStatus.partiallyReturned,
    );
    expect(
      ComputerPaymentMethodX.fromDb(
        ComputerPaymentMethod.mobileWallet.dbValue,
      ),
      ComputerPaymentMethod.mobileWallet,
    );
    expect(
      ComputerPaymentStatusX.fromDb(
        ComputerPaymentStatus.partiallyRefunded.dbValue,
      ),
      ComputerPaymentStatus.partiallyRefunded,
    );
  });

  test('sale line reports only its remaining returnable quantity', () {
    final line = ComputerDocumentLine(
      id: 'line-1',
      documentId: 'sale-1',
      productId: 'product-1',
      productName: 'Laptop',
      quantity: 3,
      unitPrice: 1000,
      unitCost: 700,
      lineSubtotal: 3000,
      warrantyMonths: 12,
      returnedQuantity: 1,
      trackSerials: false,
    );

    expect(line.returnableQuantity, 2);
  });
}
