import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/services/product_image_storage.dart';
import 'package:grill_pos/features/menu/data/menu_models.dart';

void main() {
  test('menu item image can be explicitly removed', () {
    final now = DateTime(2026, 7, 18);
    final item = MenuItem(
      id: 'item-1',
      name: 'Burger',
      categoryId: 'category-1',
      price: 100,
      imageUrl: r'C:\images\burger.png',
      createdAt: now,
      updatedAt: now,
    );

    expect(item.copyWith(clearImageUrl: true).imageUrl, isNull);
  });

  testWidgets('product image view uses a safe fallback for missing sources',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 90,
          child: ProductImageView(source: null),
        ),
      ),
    );
    expect(find.byType(ProductImagePlaceholder), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 90,
          child: ProductImageView(source: r'C:\missing\product.png'),
        ),
      ),
    );
    expect(find.byType(ProductImagePlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
