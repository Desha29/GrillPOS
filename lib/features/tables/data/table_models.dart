import 'package:equatable/equatable.dart';

enum TableStatus { available, occupied, reserved, cleaning }

class RestaurantTable extends Equatable {
  final String id;
  final int tableNumber;
  final String? name;
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;
  final String section;
  final String restaurantId;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.name,
    this.capacity = 4,
    this.status = TableStatus.available,
    this.currentOrderId,
    this.section = 'main',
    this.restaurantId = 'default',
  });

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id'] as String,
      tableNumber: map['table_number'] as int,
      name: map['name'] as String?,
      capacity: (map['capacity'] as int?) ?? 4,
      status: _parseTableStatus(map['status'] as String?),
      currentOrderId: map['current_order_id'] as String?,
      section: (map['section'] as String?) ?? 'main',
      restaurantId: (map['restaurant_id'] as String?) ?? 'default',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_number': tableNumber,
      'name': name,
      'capacity': capacity,
      'status': status.toDbString(),
      'current_order_id': currentOrderId,
      'section': section,
      'restaurant_id': restaurantId,
    };
  }

  RestaurantTable copyWith({
    String? name,
    bool clearName = false,
    int? capacity,
    TableStatus? status,
    String? currentOrderId,
    String? section,
  }) {
    return RestaurantTable(
      id: id,
      tableNumber: tableNumber,
      name: clearName ? null : name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      section: section ?? this.section,
      restaurantId: restaurantId,
    );
  }

  String get displayName => name ?? 'طاولة $tableNumber';

  static TableStatus _parseTableStatus(String? value) {
    switch (value) {
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
      case 'cleaning':
        return TableStatus.cleaning;
      default:
        return TableStatus.available;
    }
  }

  @override
  List<Object?> get props =>
      [id, tableNumber, capacity, status, currentOrderId];
}

extension TableStatusExt on TableStatus {
  String toDbString() {
    switch (this) {
      case TableStatus.available:
        return 'available';
      case TableStatus.occupied:
        return 'occupied';
      case TableStatus.reserved:
        return 'reserved';
      case TableStatus.cleaning:
        return 'cleaning';
    }
  }

  String get displayName {
    switch (this) {
      case TableStatus.available:
        return 'متاحة';
      case TableStatus.occupied:
        return 'مشغولة';
      case TableStatus.reserved:
        return 'محجوزة';
      case TableStatus.cleaning:
        return 'تنظيف';
    }
  }
}
