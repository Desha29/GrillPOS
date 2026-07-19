import 'package:equatable/equatable.dart';

enum OrderType { dineIn, takeaway, delivery }

enum OrderStatus { pending, preparing, ready, served, completed, cancelled }

enum PaymentStatus { unpaid, partial, paid }

class RestaurantOrder extends Equatable {
  final String id;
  final String orderNumber;
  final String? tableId;
  final OrderType orderType;
  final OrderStatus status;
  final double subtotal;
  final double tax;
  final double discount;
  final double totalAmount;
  final PaymentStatus paymentStatus;
  final String? notes;
  final String? cashierId;
  final String? waiterId;
  final String? shiftId;
  final String restaurantId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  const RestaurantOrder({
    required this.id,
    required this.orderNumber,
    this.tableId,
    this.orderType = OrderType.dineIn,
    this.status = OrderStatus.pending,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    this.totalAmount = 0.0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.notes,
    this.cashierId,
    this.waiterId,
    this.shiftId,
    this.restaurantId = 'default',
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory RestaurantOrder.fromMap(Map<String, dynamic> map,
      {List<OrderItem>? items}) {
    return RestaurantOrder(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      tableId: map['table_id'] as String?,
      orderType: _parseOrderType(map['order_type'] as String?),
      status: _parseOrderStatus(map['status'] as String?),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: _parsePaymentStatus(map['payment_status'] as String?),
      notes: map['notes'] as String?,
      cashierId: map['cashier_id'] as String?,
      waiterId: map['waiter_id'] as String?,
      shiftId: map['shift_id'] as String?,
      restaurantId: (map['restaurant_id'] as String?) ?? 'default',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: items ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'table_id': tableId,
      'order_type': orderType.toDbString(),
      'status': status.toDbString(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total_amount': totalAmount,
      'payment_status': paymentStatus.toDbString(),
      'notes': notes,
      'cashier_id': cashierId,
      'waiter_id': waiterId,
      'shift_id': shiftId,
      'restaurant_id': restaurantId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RestaurantOrder copyWith({
    String? tableId,
    OrderType? orderType,
    OrderStatus? status,
    double? subtotal,
    double? tax,
    double? discount,
    double? totalAmount,
    PaymentStatus? paymentStatus,
    String? notes,
    String? cashierId,
    String? waiterId,
    List<OrderItem>? items,
  }) {
    return RestaurantOrder(
      id: id,
      orderNumber: orderNumber,
      tableId: tableId ?? this.tableId,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      cashierId: cashierId ?? this.cashierId,
      waiterId: waiterId ?? this.waiterId,
      shiftId: shiftId,
      restaurantId: restaurantId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items ?? this.items,
    );
  }

  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;

  Duration get elapsed => DateTime.now().difference(createdAt);

  static OrderType _parseOrderType(String? value) {
    switch (value) {
      case 'takeaway':
        return OrderType.takeaway;
      case 'delivery':
        return OrderType.delivery;
      default:
        return OrderType.dineIn;
    }
  }

  static OrderStatus _parseOrderStatus(String? value) {
    switch (value) {
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
        return OrderStatus.served;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? value) {
    switch (value) {
      case 'partial':
        return PaymentStatus.partial;
      case 'paid':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.unpaid;
    }
  }

  @override
  List<Object?> get props =>
      [id, orderNumber, status, totalAmount, paymentStatus];
}

class OrderItem extends Equatable {
  final String id;
  final String orderId;
  final String menuItemId;
  final String itemName;
  final String? unit;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.itemName,
    this.unit,
    this.quantity = 1.0,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      menuItemId: map['menu_item_id'] as String,
      itemName: map['item_name'] as String,
      unit: map['unit'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  OrderItem copyWith({double? quantity, String? notes, String? status}) {
    return OrderItem(
      id: id,
      orderId: orderId,
      menuItemId: menuItemId,
      itemName: itemName,
      unit: unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      subtotal: unitPrice * (quantity ?? this.quantity),
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, orderId, menuItemId, quantity];
}

// Extension methods for enum serialization
extension OrderTypeExt on OrderType {
  String toDbString() {
    switch (this) {
      case OrderType.dineIn:
        return 'dine_in';
      case OrderType.takeaway:
        return 'takeaway';
      case OrderType.delivery:
        return 'delivery';
    }
  }

  String get displayName {
    switch (this) {
      case OrderType.dineIn:
        return 'داخلي';
      case OrderType.takeaway:
        return 'تيك أواي';
      case OrderType.delivery:
        return 'توصيل';
    }
  }

  String get icon {
    switch (this) {
      case OrderType.dineIn:
        return '🍽️';
      case OrderType.takeaway:
        return '🛍️';
      case OrderType.delivery:
        return '🛵';
    }
  }
}

extension OrderStatusExt on OrderStatus {
  String toDbString() {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.served:
        return 'served';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.preparing:
        return 'جاري التحضير';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.served:
        return 'تم التقديم';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }
}

extension PaymentStatusExt on PaymentStatus {
  String toDbString() {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.paid:
        return 'paid';
    }
  }
}
