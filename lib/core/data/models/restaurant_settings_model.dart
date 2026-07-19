// lib/core/data/models/restaurant_settings_model.dart

import 'dart:io';
import 'dart:typed_data';

class RestaurantSettingsModel {
  static const String SINGLETON_ID = 'restaurant_settings_singleton';

  final String id;
  final String restaurantName;
  final String? restaurantAddress;
  final String? restaurantPhone;
  final String? restaurantEmail;
  final String? logoPath;
  final double taxRate;
  final String currency;
  final String invoicePrefix;
  final int lastInvoiceNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  Uint8List? _logoBytes;

  RestaurantSettingsModel({
    String? id,
    required this.restaurantName,
    this.restaurantAddress,
    this.restaurantPhone,
    this.restaurantEmail,
    this.logoPath,
    this.taxRate = 0.0,
    this.currency = 'EGP',
    this.invoicePrefix = 'INV',
    this.lastInvoiceNumber = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? SINGLETON_ID,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Future<Uint8List?> getLogoBytes() async {
    if (_logoBytes != null) return _logoBytes;

    if (logoPath != null && logoPath!.isNotEmpty) {
      final file = File(logoPath!);
      if (await file.exists()) {
        _logoBytes = await file.readAsBytes();
        return _logoBytes;
      }
    }
    return null;
  }

  String generateNextInvoiceNumber() {
    final nextNumber = lastInvoiceNumber + 1;
    return '$invoicePrefix-${nextNumber.toString().padLeft(6, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress,
      'restaurant_phone': restaurantPhone,
      'restaurant_email': restaurantEmail,
      'logo_path': logoPath,
      'tax_rate': taxRate,
      'currency': currency,
      'invoice_prefix': invoicePrefix,
      'last_invoice_number': lastInvoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSQLite() => toJson();

  factory RestaurantSettingsModel.fromSQLite(Map<String, dynamic> map) {
    return RestaurantSettingsModel(
      id: map['id'] as String,
      restaurantName: map['restaurant_name'] as String,
      restaurantAddress: map['restaurant_address'] as String?,
      restaurantPhone: map['restaurant_phone'] as String?,
      restaurantEmail: map['restaurant_email'] as String?,
      logoPath: map['logo_path'] as String?,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'EGP',
      invoicePrefix: map['invoice_prefix'] as String? ?? 'INV',
      lastInvoiceNumber: (map['last_invoice_number'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory RestaurantSettingsModel.defaultSettings() {
    return RestaurantSettingsModel(
      restaurantName: 'GrillPOS',
      restaurantAddress: 'Address not set',
      restaurantPhone: '0000000000',
      currency: 'EGP',
      invoicePrefix: 'INV',
    );
  }

  RestaurantSettingsModel copyWith({
    String? restaurantName,
    String? restaurantAddress,
    String? restaurantPhone,
    String? restaurantEmail,
    String? logoPath,
    double? taxRate,
    String? currency,
    String? invoicePrefix,
    int? lastInvoiceNumber,
  }) {
    return RestaurantSettingsModel(
      id: id,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      restaurantEmail: restaurantEmail ?? this.restaurantEmail,
      logoPath: logoPath ?? this.logoPath,
      taxRate: taxRate ?? this.taxRate,
      currency: currency ?? this.currency,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      lastInvoiceNumber: lastInvoiceNumber ?? this.lastInvoiceNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
