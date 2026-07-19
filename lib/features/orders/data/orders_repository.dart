import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/services/persistence_initializer.dart';
import 'order_models.dart';

class OrdersRepository {
  static const _uuid = Uuid();

  OrdersRepository({Database? database}) : _database = database;

  final Database? _database;

  // ─── Stream for real-time order updates ─────────────────────────────
  final _ordersController = StreamController<void>.broadcast();
  Stream<void> get ordersStream => _ordersController.stream;

  void _notifyChange() {
    if (!_ordersController.isClosed) {
      _ordersController.add(null);
    }
  }

  void dispose() {
    _ordersController.close();
  }

  Database get _db =>
      _database ??
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  /// Legal forward-only lifecycle actions for an order.
  ///
  /// Cancellation is deliberately hidden once money has been collected. A
  /// refund must be recorded explicitly before a financial order can be
  /// cancelled.
  static List<OrderStatus> legalNextStatuses(RestaurantOrder order) {
    final canCancel = order.paymentStatus == PaymentStatus.unpaid;
    return switch (order.status) {
      OrderStatus.pending => [
          OrderStatus.preparing,
          if (canCancel) OrderStatus.cancelled,
        ],
      OrderStatus.preparing => [
          OrderStatus.ready,
          if (canCancel) OrderStatus.cancelled,
        ],
      OrderStatus.ready => [
          OrderStatus.served,
          if (canCancel) OrderStatus.cancelled,
        ],
      OrderStatus.served => order.paymentStatus == PaymentStatus.paid
          ? const [OrderStatus.completed]
          : const [],
      OrderStatus.completed || OrderStatus.cancelled => const [],
    };
  }

  Future<List<RestaurantOrder>> getOrders({bool onlyActive = false}) async {
    final db = _db;
    final where = onlyActive ? "status NOT IN ('completed','cancelled')" : null;
    final orderRows = await db.query(
      'orders',
      where: where,
      orderBy: 'created_at DESC',
    );
    if (orderRows.isEmpty) return const [];

    // Load all related lines once. This avoids one query per order on large
    // history screens while preserving line ordering within each order.
    final ids = orderRows.map((row) => row['id'] as String).toList();
    final itemsByOrder = <String, List<OrderItem>>{};
    const chunkSize = 500; // Safely below SQLite's common parameter limit.
    for (var start = 0; start < ids.length; start += chunkSize) {
      final candidateEnd = start + chunkSize;
      final end = candidateEnd < ids.length ? candidateEnd : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemRows = await db.query(
        'order_items',
        where: 'order_id IN ($placeholders)',
        whereArgs: chunk,
        orderBy: 'created_at ASC',
      );
      for (final row in itemRows) {
        final item = OrderItem.fromMap(row);
        itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
      }
    }
    return orderRows
        .map(
          (row) => RestaurantOrder.fromMap(
            row,
            items: itemsByOrder[row['id'] as String] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<RestaurantOrder?> getOrderById(String id) async {
    final db = _db;
    final rows =
        await db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final items = await _itemsForOrder(id);
    return RestaurantOrder.fromMap(rows.first, items: items);
  }

  Future<RestaurantOrder> createOrder({
    String? tableId,
    OrderType orderType = OrderType.dineIn,
    String? cashierId,
    String? waiterId,
    String? notes,
    double taxRate = 0.15,
  }) async {
    final db = _db;
    final now = DateTime.now();
    final id = _uuid.v4();
    final orderNo = _generateOrderNumber(now);

    final order = RestaurantOrder(
      id: id,
      orderNumber: orderNo,
      tableId: tableId,
      orderType: orderType,
      cashierId: cashierId,
      waiterId: waiterId,
      notes: notes,
      tax: 0.0, // Will be calculated
      createdAt: now,
      updatedAt: now,
    );
    // We Store the taxRate in the order meta if needed, but for now we just use it in recalculate.
    // Actually, I'll add tax_rate to orders table later. For now just pass it.

    await db.insert('orders', order.toMap());
    _notifyChange();
    return order;
  }

  /// Creates the order header and every line in one database transaction.
  /// No incomplete order is left behind if any line fails validation/insertion.
  Future<RestaurantOrder> createOrderWithItems({
    required List<NewOrderLine> items,
    required String cashierId,
    String? tableId,
    OrderType orderType = OrderType.dineIn,
    String? waiterId,
    String? notes,
    double taxRate = 0.15,
  }) async {
    if (items.isEmpty) {
      throw const OrdersIntegrityException(
        'أضف صنفاً واحداً على الأقل قبل إنشاء الطلب.',
      );
    }
    if (taxRate < 0) {
      throw const OrdersIntegrityException('نسبة الضريبة غير صالحة.');
    }
    for (final line in items) {
      if (line.menuItemId.trim().isEmpty || line.itemName.trim().isEmpty) {
        throw const OrdersIntegrityException('بيانات صنف الطلب غير مكتملة.');
      }
      if (line.quantity <= 0 || line.unitPrice < 0) {
        throw const OrdersIntegrityException('كمية أو سعر الصنف غير صالح.');
      }
    }

    final now = DateTime.now();
    final orderId = _uuid.v4();
    final orderNumber = _generateOrderNumber(now);
    final orderItems = items
        .map(
          (line) => OrderItem(
            id: _uuid.v4(),
            orderId: orderId,
            menuItemId: line.menuItemId,
            itemName: line.itemName,
            unit: line.unit,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            subtotal: _toCents(line.unitPrice * line.quantity) / 100,
            notes: line.notes,
            createdAt: now,
          ),
        )
        .toList(growable: false);
    final subtotalCents = orderItems.fold<int>(
      0,
      (sum, item) => sum + _toCents(item.subtotal),
    );
    final taxCents = (subtotalCents * taxRate).round();
    final order = RestaurantOrder(
      id: orderId,
      orderNumber: orderNumber,
      tableId: tableId,
      orderType: orderType,
      subtotal: subtotalCents / 100,
      tax: taxCents / 100,
      totalAmount: (subtotalCents + taxCents) / 100,
      notes: notes,
      cashierId: cashierId,
      waiterId: waiterId,
      createdAt: now,
      updatedAt: now,
      items: orderItems,
    );

    await _db.transaction((txn) async {
      await _requireActiveActor(txn, cashierId);
      if (tableId != null) {
        final tables = await txn.query(
          'restaurant_tables',
          columns: const ['id', 'current_order_id'],
          where: 'id = ?',
          whereArgs: [tableId],
          limit: 1,
        );
        if (tables.isEmpty) {
          throw const OrdersIntegrityException('الطاولة المحددة غير موجودة.');
        }
        final currentOrderId = tables.single['current_order_id'] as String?;
        if (currentOrderId?.isNotEmpty == true) {
          final active = await txn.rawQuery(
            '''
            SELECT id FROM orders
            WHERE id = ? AND status NOT IN ('completed', 'cancelled')
            LIMIT 1
            ''',
            [currentOrderId],
          );
          if (active.isNotEmpty) {
            throw const OrdersIntegrityException(
              'الطاولة مشغولة بطلب نشط آخر.',
            );
          }
        }
      }
      await txn.insert('orders', order.toMap());
      for (final item in orderItems) {
        await txn.insert('order_items', item.toMap());
      }
      if (tableId != null) {
        final changed = await txn.update(
          'restaurant_tables',
          {'current_order_id': orderId, 'status': 'occupied'},
          where: 'id = ?',
          whereArgs: [tableId],
        );
        if (changed != 1) {
          throw const OrdersIntegrityException(
            'تعذر حجز الطاولة للطلب الجديد.',
          );
        }
      }
    });
    _notifyChange();
    return order;
  }

  Future<void> updateOrder(RestaurantOrder order) async {
    final db = _db;
    final values = order.toMap()
      ..remove('id')
      ..remove('status')
      ..remove('payment_status')
      ..remove('created_at');
    await db.update('orders', values, where: 'id = ?', whereArgs: [order.id]);
    _notifyChange();
  }

  Future<void> transitionStatus({
    required String orderId,
    required OrderStatus expectedCurrent,
    required OrderStatus next,
    required String actorId,
  }) async {
    final db = _db;
    await db.transaction((txn) async {
      await _requireActiveActor(txn, actorId);
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const OrdersIntegrityException('الطلب المطلوب غير موجود.');
      }

      final order = RestaurantOrder.fromMap(rows.first);
      if (order.status != expectedCurrent) {
        throw const OrdersIntegrityException(
          'تم تحديث الطلب من جهاز آخر. حدّث القائمة وحاول مرة أخرى.',
        );
      }

      final legal = legalNextStatuses(order);
      if (!legal.contains(next)) {
        throw OrdersIntegrityException(
          order.status == OrderStatus.completed ||
                  order.status == OrderStatus.cancelled
              ? 'لا يمكن تعديل طلب مكتمل أو ملغي.'
              : next == OrderStatus.cancelled &&
                      order.paymentStatus != PaymentStatus.unpaid
                  ? 'لا يمكن إلغاء طلب مدفوع كلياً أو جزئياً قبل تسجيل استرداد صريح.'
                  : 'انتقال حالة الطلب غير مسموح.',
        );
      }

      final paidCents = await _paidCents(txn, orderId);
      if (next == OrderStatus.cancelled && paidCents > 0) {
        throw const OrdersIntegrityException(
          'لا يمكن إلغاء طلب يحتوي على دفعات قبل تسجيل الاسترداد.',
        );
      }
      if (next == OrderStatus.completed) {
        final totalCents = _toCents(order.totalAmount);
        if (order.paymentStatus != PaymentStatus.paid ||
            paidCents < totalCents) {
          throw const OrdersIntegrityException(
            'يجب سداد الطلب بالكامل قبل إكماله.',
          );
        }
      }

      final changed = await txn.update(
        'orders',
        {
          'status': next.toDbString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [orderId, expectedCurrent.toDbString()],
      );
      if (changed != 1) {
        throw const OrdersIntegrityException(
          'تعذر تحديث الطلب بأمان. حدّث القائمة وحاول مرة أخرى.',
        );
      }
      if (next == OrderStatus.completed || next == OrderStatus.cancelled) {
        await txn.update(
          'restaurant_tables',
          {'current_order_id': null, 'status': 'available'},
          where: 'current_order_id = ?',
          whereArgs: [orderId],
        );
      }
    });
    _notifyChange();
  }

  Future<void> addOrderItem({
    required String orderId,
    required String menuItemId,
    required String itemName,
    String? unit,
    required double quantity,
    required double unitPrice,
    String? notes,
    double taxRate = 0.15,
  }) async {
    final db = _db;
    final item = OrderItem(
      id: _uuid.v4(),
      orderId: orderId,
      menuItemId: menuItemId,
      itemName: itemName,
      unit: unit,
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: unitPrice * quantity,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await db.insert('order_items', item.toMap());
    await _recalculateOrder(orderId, taxRate: taxRate);
    _notifyChange();
  }

  Future<void> removeOrderItem(String itemId) async {
    final db = _db;
    final rows = await db.query('order_items',
        where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (rows.isEmpty) return;

    final orderId = rows.first['order_id'] as String;
    await db.delete('order_items', where: 'id = ?', whereArgs: [itemId]);
    await _recalculateOrder(orderId);
    _notifyChange();
  }

  /// Records exactly the unpaid balance as a completed payment.
  ///
  /// Monetary values are rounded to integer cents before comparison/storage,
  /// preventing fractional-cent drift. [actorId] is required and must identify
  /// an active application user.
  Future<String> recordRemainingPayment({
    required String orderId,
    required String actorId,
    String method = 'cash',
    String? referenceNumber,
  }) async {
    final db = _db;
    final paymentId = _uuid.v4();
    final normalizedMethod = method.trim();
    if (normalizedMethod.isEmpty) {
      throw const OrdersIntegrityException('اختر طريقة دفع صحيحة.');
    }

    await db.transaction((txn) async {
      await _requireActiveActor(txn, actorId);
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const OrdersIntegrityException('الطلب المطلوب غير موجود.');
      }
      final order = RestaurantOrder.fromMap(rows.first);
      if (order.status == OrderStatus.cancelled) {
        throw const OrdersIntegrityException('لا يمكن دفع طلب ملغي.');
      }

      final totalCents = _toCents(order.totalAmount);
      final paidCents = await _paidCents(txn, orderId);
      final remainingCents = totalCents - paidCents;
      if (totalCents <= 0) {
        throw const OrdersIntegrityException(
          'لا يمكن تسجيل دفعة لطلب قيمته صفر.',
        );
      }
      if (remainingCents <= 0) {
        throw const OrdersIntegrityException('تم سداد الطلب بالكامل بالفعل.');
      }

      final now = DateTime.now().toIso8601String();
      await txn.insert('payments', {
        'id': paymentId,
        'order_id': orderId,
        'amount': remainingCents / 100,
        'method': normalizedMethod,
        'status': 'completed',
        'reference_number': referenceNumber?.trim().isEmpty == true
            ? null
            : referenceNumber?.trim(),
        'cashier_id': actorId.trim(),
        'created_at': now,
      });
      await txn.update(
        'orders',
        {
          'payment_status': PaymentStatus.paid.toDbString(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
    _notifyChange();
    return paymentId;
  }

  static int _toCents(double amount) => (amount * 100).round();

  static Future<int> _paidCents(
      DatabaseExecutor executor, String orderId) async {
    final rows = await executor.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS paid
      FROM payments
      WHERE order_id = ? AND status = 'completed'
      ''',
      [orderId],
    );
    return _toCents((rows.single['paid'] as num?)?.toDouble() ?? 0);
  }

  static Future<void> _requireActiveActor(
      DatabaseExecutor executor, String actorId) async {
    final normalized = actorId.trim();
    if (normalized.isEmpty) {
      throw const OrdersIntegrityException(
        'يجب تسجيل الدخول لتنفيذ هذا الإجراء.',
      );
    }
    final rows = await executor.query(
      'users',
      columns: const ['id'],
      where: '(id = ? OR username = ?) AND is_active = 1',
      whereArgs: [normalized, normalized],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const OrdersIntegrityException(
        'المستخدم الحالي غير صالح أو غير نشط.',
      );
    }
  }

  Future<List<OrderItem>> _itemsForOrder(String orderId) async {
    final db = _db;
    final rows = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at ASC',
    );
    return rows.map(OrderItem.fromMap).toList();
  }

  Future<void> _recalculateOrder(String orderId,
      {double taxRate = 0.15}) async {
    final db = _db;
    final items = await _itemsForOrder(orderId);
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);
    final tax = subtotal * taxRate;
    final discount = 0.0;
    final total = subtotal + tax - discount;

    await db.update(
      'orders',
      {
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total_amount': total,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  String _generateOrderNumber(DateTime now) {
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final milliseconds = now.millisecond.toString().padLeft(3, '0');
    final uniqueSuffix =
        _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
    return 'ORD-$date-$time$milliseconds-$uniqueSuffix';
  }
}

class OrdersIntegrityException implements Exception {
  const OrdersIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewOrderLine {
  const NewOrderLine({
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    this.unit,
    this.notes,
  });

  final String menuItemId;
  final String itemName;
  final String? unit;
  final double quantity;
  final double unitPrice;
  final String? notes;
}
