import 'package:equatable/equatable.dart';

class MenuCategory extends Equatable {
  final String id;
  final String name;
  final String? nameAr;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final String restaurantId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuCategory({
    required this.id,
    required this.name,
    this.nameAr,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.restaurantId = 'default',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      nameAr: map['name_ar'] as String?,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      restaurantId: (map['restaurant_id'] as String?) ?? 'default',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'restaurant_id': restaurantId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MenuCategory copyWith({
    String? name,
    String? nameAr,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) {
    return MenuCategory(
      id: id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      restaurantId: restaurantId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Display name (Arabic if available, otherwise English)
  String get displayName => nameAr ?? name;

  @override
  List<Object?> get props => [id, name, nameAr, isActive, sortOrder];
}

class MenuItem extends Equatable {
  final String id;
  final String name;
  final String? nameAr;
  final String categoryId;
  final double price;
  final String? imageUrl;
  final String? description;
  final String? unit; // e.g. 'كيلو', 'قطعة'
  final bool isAvailable;
  final int sortOrder;
  final int preparationTime;
  final String restaurantId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuItem({
    required this.id,
    required this.name,
    this.nameAr,
    required this.categoryId,
    required this.price,
    this.imageUrl,
    this.description,
    this.unit,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.preparationTime = 10,
    this.restaurantId = 'default',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      nameAr: map['name_ar'] as String?,
      categoryId: map['category_id'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String?,
      unit: map['unit'] as String?,
      isAvailable: (map['is_available'] as int?) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      preparationTime: (map['preparation_time'] as int?) ?? 10,
      restaurantId: (map['restaurant_id'] as String?) ?? 'default',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'category_id': categoryId,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'unit': unit,
      'is_available': isAvailable ? 1 : 0,
      'sort_order': sortOrder,
      'preparation_time': preparationTime,
      'restaurant_id': restaurantId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MenuItem copyWith({
    String? name,
    String? nameAr,
    String? categoryId,
    double? price,
    String? imageUrl,
    bool clearImageUrl = false,
    String? description,
    bool clearDescription = false,
    String? unit,
    bool clearUnit = false,
    bool? isAvailable,
    int? sortOrder,
    int? preparationTime,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      description: clearDescription ? null : (description ?? this.description),
      unit: clearUnit ? null : (unit ?? this.unit),
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      preparationTime: preparationTime ?? this.preparationTime,
      restaurantId: restaurantId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String get displayName => nameAr ?? name;

  @override
  List<Object?> get props => [
        id,
        name,
        categoryId,
        price,
        imageUrl,
        description,
        unit,
        isAvailable,
      ];
}
