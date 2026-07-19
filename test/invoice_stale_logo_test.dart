import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/features/invoice/presentation/invoice_screen.dart';
import 'package:grill_pos/features/orders/data/order_models.dart';

void main() {
  testWidgets('missing configured logo falls back without crashing checkout',
      (tester) async {
    final now = DateTime(2026, 7, 19, 12);
    final order = RestaurantOrder(
      id: 'invoice-logo-test',
      orderNumber: 'INV-001',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceScreen(
          order: order,
          restaurantLogo:
              r'D:\Work\GrillPOS\assets\images\grillpos\logo_icon.png',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
  });
}
