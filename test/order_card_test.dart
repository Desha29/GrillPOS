import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/components/order_card.dart';
import 'package:grill_pos/features/orders/data/order_models.dart';

void main() {
  testWidgets('recent order card lays out without intrinsic dimension errors',
      (tester) async {
    final now = DateTime.now();
    final order = RestaurantOrder(
      id: 'order-1',
      orderNumber: '1001',
      totalAmount: 240,
      createdAt: now.subtract(const Duration(minutes: 8)),
      updatedAt: now,
      items: [
        OrderItem(
          id: 'item-1',
          orderId: 'order-1',
          menuItemId: 'menu-1',
          itemName: 'Meal',
          unitPrice: 240,
          subtotal: 240,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: OrderCard(order: order, onTap: () {}, compact: true),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('#1001'), findsOneWidget);
  });
}
