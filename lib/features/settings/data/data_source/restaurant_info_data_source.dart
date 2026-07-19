import 'package:grill_pos/core/data/services/persistence_initializer.dart';
import '../models/restaurant_info_model.dart';

class RestaurantInfoDataSource {
  static const String _table = 'restaurant_settings';
  static const String _id = 'restaurant_settings_singleton';

  Future<void> saveRestaurantInfo(RestaurantInfo restaurantInfo) async {
    try {
      final db = PersistenceInitializer.persistenceManager!.sqliteManager;

      final count = await db.update(
          _table,
          {
            'restaurant_name': restaurantInfo.name,
            'restaurant_address': restaurantInfo.address,
            'restaurant_phone': restaurantInfo.phone,
            'restaurant_email': restaurantInfo.email,
            'tax_number': restaurantInfo.vat,
            'logo_path': restaurantInfo.logoPath ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [_id]);

      if (count == 0) {
        // Fallback insert if not exists (should be rare)
        await db.insert(_table, {
          'id': _id,
          'restaurant_name': restaurantInfo.name,
          'restaurant_address': restaurantInfo.address,
          'restaurant_phone': restaurantInfo.phone,
          'restaurant_email': restaurantInfo.email,
          'tax_number': restaurantInfo.vat,
          'logo_path': restaurantInfo.logoPath ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          // Defaults for others will be used
        });
      }
    } catch (e) {
      throw Exception('Failed to save restaurant info: $e');
    }
  }

  Future<RestaurantInfo?> getRestaurantInfo() async {
    try {
      final db = PersistenceInitializer.persistenceManager!.sqliteManager;
      final results = await db.query(_table, where: 'id = ?', whereArgs: [_id]);

      if (results.isNotEmpty) {
        final row = results.first;
        return RestaurantInfo(
          name: row['restaurant_name'] as String,
          address: (row['restaurant_address'] as String?) ?? 'Alkhanka',
          phone: (row['restaurant_phone'] as String?) ?? '01000000000',
          email: (row['restaurant_email'] as String?) ?? 'GrillPOS@GrillPOS',
          vat: (row['tax_number'] as String?) ?? '0000000000000',
          logoPath: (row['logo_path'] as String?) ??
              'assets/images/grillpos/logo_icon.png',
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get restaurant info: $e');
    }
  }

  Future<void> deleteRestaurantInfo() async {}

  Future<bool> hasRestaurantInfo() async {
    final info = await getRestaurantInfo();
    return info != null;
  }

  RestaurantInfo getDefaultRestaurantInfo() {
    return RestaurantInfo(
      name: 'GrillPOS',
      phone: '01000000000',
      email: 'Grill@grill.com',
      address: "Alkhanka",
      vat: '0000000000000',
      logoPath: 'assets/images/grillpos/logo_icon.png',
    );
  }
}
