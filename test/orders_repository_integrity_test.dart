import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';
import 'package:grill_pos/features/orders/data/order_models.dart';
import 'package:grill_pos/features/orders/data/orders_repository.dart';

void main() {
  late Directory directory;
  late SQLiteManager manager;
  late OrdersRepository repository;

  const actorId = 'cashier-orders-test';
  const menuItemId = 'menu-orders-test';

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('orders_integrity_');
    manager = SQLiteManager(
      databasePath:
          '${directory.path}${Platform.pathSeparator}orders_integrity.db',
    );
    await manager.initialize();
    repository = OrdersRepository(database: manager.database);

    final now = DateTime.now().toIso8601String();
    await manager.database.insert('users', {
      'id': actorId,
      'username': actorId,
      'display_name': 'Orders Cashier',
      'password_hash': 'test-only',
      'role': 'cashier',
      'is_active': 1,
      'created_at': now,
    });
    await manager.database.insert('menu_categories', {
      'id': 'category-orders-test',
      'name': 'Test',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await manager.database.insert('menu_items', {
      'id': menuItemId,
      'name': 'Test meal',
      'category_id': 'category-orders-test',
      'price': 10.13,
      'is_available': 1,
      'created_at': now,
      'updated_at': now,
    });
    for (final table in const [
      ('table-orders-test', 901),
      ('table-orders-occupied', 902),
    ]) {
      await manager.database.insert('restaurant_tables', {
        'id': table.$1,
        'table_number': table.$2,
        'status': 'available',
      });
    }
  });

  tearDownAll(() async {
    repository.dispose();
    await manager.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<RestaurantOrder> orderWithTotal(double total) async {
    final order = await repository.createOrder(cashierId: actorId);
    await manager.database.update(
      'orders',
      {'subtotal': total, 'total_amount': total},
      where: 'id = ?',
      whereArgs: [order.id],
    );
    return (await repository.getOrderById(order.id))!;
  }

  Future<RestaurantOrder> moveToServed(RestaurantOrder order) async {
    var current = order;
    while (current.status != OrderStatus.served) {
      final next = switch (current.status) {
        OrderStatus.pending => OrderStatus.preparing,
        OrderStatus.preparing => OrderStatus.ready,
        OrderStatus.ready => OrderStatus.served,
        _ => throw StateError('Order cannot progress to served'),
      };
      await repository.transitionStatus(
        orderId: current.id,
        expectedCurrent: current.status,
        next: next,
        actorId: actorId,
      );
      current = (await repository.getOrderById(current.id))!;
    }
    return current;
  }

  test('remaining payment inserts a cent-rounded, attributed payment row',
      () async {
    final order = await orderWithTotal(10.126);

    final paymentId = await repository.recordRemainingPayment(
      orderId: order.id,
      actorId: actorId,
      method: 'card',
      referenceNumber: 'AUTH-100',
    );

    final payment = (await manager.database.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    ))
        .single;
    expect(payment['amount'], 10.13);
    expect(payment['method'], 'card');
    expect(payment['reference_number'], 'AUTH-100');
    expect(payment['cashier_id'], actorId);
    expect(
      (await repository.getOrderById(order.id))!.paymentStatus,
      PaymentStatus.paid,
    );
  });

  test('unpaid completion and backwards lifecycle transitions are rejected',
      () async {
    var order = await orderWithTotal(50);
    await repository.transitionStatus(
      orderId: order.id,
      expectedCurrent: OrderStatus.pending,
      next: OrderStatus.preparing,
      actorId: actorId,
    );
    order = (await repository.getOrderById(order.id))!;

    await expectLater(
      repository.transitionStatus(
        orderId: order.id,
        expectedCurrent: order.status,
        next: OrderStatus.pending,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );

    order = await moveToServed(order);
    await expectLater(
      repository.transitionStatus(
        orderId: order.id,
        expectedCurrent: order.status,
        next: OrderStatus.completed,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
  });

  test('paid orders cannot be cancelled and completed orders are terminal',
      () async {
    var paidOrder = await orderWithTotal(75);
    await repository.recordRemainingPayment(
      orderId: paidOrder.id,
      actorId: actorId,
    );
    paidOrder = (await repository.getOrderById(paidOrder.id))!;

    await expectLater(
      repository.transitionStatus(
        orderId: paidOrder.id,
        expectedCurrent: paidOrder.status,
        next: OrderStatus.cancelled,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );

    paidOrder = await moveToServed(paidOrder);
    await repository.transitionStatus(
      orderId: paidOrder.id,
      expectedCurrent: paidOrder.status,
      next: OrderStatus.completed,
      actorId: actorId,
    );
    final completed = (await repository.getOrderById(paidOrder.id))!;
    await expectLater(
      repository.transitionStatus(
        orderId: completed.id,
        expectedCurrent: completed.status,
        next: OrderStatus.preparing,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
  });

  test('partially paid orders cannot be cancelled', () async {
    final order = await orderWithTotal(100);
    final now = DateTime.now().toIso8601String();
    await manager.database.insert('payments', {
      'id': 'partial-${order.id}',
      'order_id': order.id,
      'amount': 20,
      'method': 'cash',
      'status': 'completed',
      'cashier_id': actorId,
      'created_at': now,
    });
    await manager.database.update(
      'orders',
      {'payment_status': 'partial'},
      where: 'id = ?',
      whereArgs: [order.id],
    );
    final partial = (await repository.getOrderById(order.id))!;

    await expectLater(
      repository.transitionStatus(
        orderId: partial.id,
        expectedCurrent: partial.status,
        next: OrderStatus.cancelled,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
  });

  test('cancelled orders are terminal', () async {
    final order = await orderWithTotal(25);
    await repository.transitionStatus(
      orderId: order.id,
      expectedCurrent: order.status,
      next: OrderStatus.cancelled,
      actorId: actorId,
    );
    await expectLater(
      repository.transitionStatus(
        orderId: order.id,
        expectedCurrent: OrderStatus.cancelled,
        next: OrderStatus.preparing,
        actorId: actorId,
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
  });

  test('atomic checkout creates every line and collision-safe numbers',
      () async {
    const lines = [
      NewOrderLine(
        menuItemId: menuItemId,
        itemName: 'Test meal',
        quantity: 2,
        unitPrice: 10.13,
      ),
    ];
    final first = await repository.createOrderWithItems(
      items: lines,
      cashierId: actorId,
    );
    final second = await repository.createOrderWithItems(
      items: lines,
      cashierId: actorId,
    );

    expect(first.orderNumber, isNot(second.orderNumber));
    expect(
        first.orderNumber, matches(RegExp(r'^ORD-\d{8}-\d{9}-[A-F0-9]{6}$')));
    expect(first.items, hasLength(1));
    expect(first.totalAmount, 23.3);
    expect(
      await manager.database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [first.id],
      ),
      hasLength(1),
    );
  });

  test('atomic dine-in checkout occupies and terminal transition frees table',
      () async {
    var order = await repository.createOrderWithItems(
      items: const [
        NewOrderLine(
          menuItemId: menuItemId,
          itemName: 'Test meal',
          quantity: 1,
          unitPrice: 10.13,
        ),
      ],
      cashierId: actorId,
      tableId: 'table-orders-test',
    );
    var table = (await manager.database.query(
      'restaurant_tables',
      where: 'id = ?',
      whereArgs: ['table-orders-test'],
    ))
        .single;
    expect(table['status'], 'occupied');
    expect(table['current_order_id'], order.id);

    await repository.recordRemainingPayment(
      orderId: order.id,
      actorId: actorId,
    );
    order = (await repository.getOrderById(order.id))!;
    order = await moveToServed(order);
    await repository.transitionStatus(
      orderId: order.id,
      expectedCurrent: order.status,
      next: OrderStatus.completed,
      actorId: actorId,
    );
    table = (await manager.database.query(
      'restaurant_tables',
      where: 'id = ?',
      whereArgs: ['table-orders-test'],
    ))
        .single;
    expect(table['status'], 'available');
    expect(table['current_order_id'], isNull);
  });

  test('atomic checkout rejects a table with another active order', () async {
    const lines = [
      NewOrderLine(
        menuItemId: menuItemId,
        itemName: 'Test meal',
        quantity: 1,
        unitPrice: 10.13,
      ),
    ];
    await repository.createOrderWithItems(
      items: lines,
      cashierId: actorId,
      tableId: 'table-orders-occupied',
    );
    final before = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];

    await expectLater(
      repository.createOrderWithItems(
        items: lines,
        cashierId: actorId,
        tableId: 'table-orders-occupied',
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
    final after = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];
    expect(after, before);
  });

  test('atomic checkout rejects an unauthenticated actor without writes',
      () async {
    final before = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];
    await expectLater(
      repository.createOrderWithItems(
        items: const [
          NewOrderLine(
            menuItemId: menuItemId,
            itemName: 'Test meal',
            quantity: 1,
            unitPrice: 10.13,
          ),
        ],
        cashierId: 'missing-actor',
      ),
      throwsA(isA<OrdersIntegrityException>()),
    );
    final after = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];
    expect(after, before);
  });

  test('atomic checkout rolls back header when a line insert fails', () async {
    final before = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];

    await expectLater(
      repository.createOrderWithItems(
        items: const [
          NewOrderLine(
            menuItemId: 'missing-menu-item',
            itemName: 'Missing',
            quantity: 1,
            unitPrice: 10,
          ),
        ],
        cashierId: actorId,
      ),
      throwsA(anything),
    );

    final after = (await manager.database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders',
    ))
        .single['count'];
    expect(after, before);
  });
}
