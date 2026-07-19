import 'package:equatable/equatable.dart';

class InventoryProduct extends Equatable {
  const InventoryProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.stock,
    required this.minStock,
    this.sku,
    this.barcode,
    this.brand,
    this.model,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    this.supplierName,
    this.warrantyMonths = 0,
    this.trackSerials = false,
    this.productType = 'merchandise',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? brand;
  final String? model;
  final double price;
  final double cost;
  final double stock;
  final double minStock;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String? supplierName;
  final int warrantyMonths;
  final bool trackSerials;
  final String productType;
  final bool isActive;

  bool get isLowStock => stock <= minStock;
  double get inventoryValue => stock * cost;
  String get descriptor => [brand, model]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' ');

  factory InventoryProduct.fromMap(Map<String, dynamic> map) =>
      InventoryProduct(
        id: map['id'] as String,
        name: map['name'] as String,
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
        price: (map['price'] as num?)?.toDouble() ?? 0,
        cost: (map['cost'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
        categoryId: map['category_id'] as String?,
        categoryName: map['category_name'] as String?,
        supplierId: map['supplier_id'] as String?,
        supplierName: map['supplier_name'] as String?,
        warrantyMonths: (map['warranty_months'] as num?)?.toInt() ?? 0,
        trackSerials: (map['track_serials'] as num?)?.toInt() == 1,
        productType: (map['product_type'] as String?) ?? 'merchandise',
        isActive: (map['is_active'] as num?)?.toInt() != 0,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        barcode,
        price,
        cost,
        stock,
        minStock,
        supplierId,
        warrantyMonths,
        trackSerials,
      ];
}

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? notes;

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        contactName: map['contact_name'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        taxNumber: map['tax_number'] as String?,
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, name, phone, email, taxNumber];
}

class ProductSerial extends Equatable {
  const ProductSerial({
    required this.id,
    required this.productId,
    required this.serialNumber,
    required this.status,
    required this.purchaseCost,
    this.warrantyExpiry,
  });

  final String id;
  final String productId;
  final String serialNumber;
  final String status;
  final double purchaseCost;
  final DateTime? warrantyExpiry;

  factory ProductSerial.fromMap(Map<String, dynamic> map) => ProductSerial(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        serialNumber: map['serial_number'] as String,
        status: map['status'] as String,
        purchaseCost: (map['purchase_cost'] as num?)?.toDouble() ?? 0,
        warrantyExpiry: map['warranty_expiry'] == null
            ? null
            : DateTime.tryParse(map['warranty_expiry'] as String),
      );

  @override
  List<Object?> get props =>
      [id, productId, serialNumber, status, purchaseCost, warrantyExpiry];
}

class InventoryStats extends Equatable {
  const InventoryStats({
    this.products = 0,
    this.lowStock = 0,
    this.serializedUnits = 0,
    this.inventoryValue = 0,
  });

  final int products;
  final int lowStock;
  final int serializedUnits;
  final double inventoryValue;

  @override
  List<Object> get props =>
      [products, lowStock, serializedUnits, inventoryValue];
}

class NewInventoryProductInput {
  const NewInventoryProductInput({
    required this.name,
    required this.price,
    required this.cost,
    required this.minStock,
    this.openingStock = 0,
    this.sku,
    this.barcode,
    this.brand,
    this.model,
    this.categoryName,
    this.supplierId,
    this.warrantyMonths = 0,
    this.trackSerials = false,
    this.serialNumbers = const [],
  });

  final String name;
  final String? sku;
  final String? barcode;
  final String? brand;
  final String? model;
  final double price;
  final double cost;
  final double openingStock;
  final double minStock;
  final String? categoryName;
  final String? supplierId;
  final int warrantyMonths;
  final bool trackSerials;
  final List<String> serialNumbers;
}

class NewSupplierInput {
  const NewSupplierInput({
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
  });

  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? notes;
}
