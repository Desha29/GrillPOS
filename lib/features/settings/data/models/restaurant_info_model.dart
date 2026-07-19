// restaurant_info_model.dart

class RestaurantInfo {
  String name;
  String address;
  String phone;
  String email;
  String vat;
  String? logoPath;

  RestaurantInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.vat,
    this.logoPath,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'vat': vat,
      'logoPath': logoPath ?? '',
    };
  }

  factory RestaurantInfo.fromMap(Map<dynamic, dynamic> map) {
    return RestaurantInfo(
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      vat: map['vat']?.toString() ?? '',
      logoPath: map['logoPath']?.toString(),
    );
  }
}
