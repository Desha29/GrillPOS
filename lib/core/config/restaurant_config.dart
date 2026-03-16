import 'dart:convert';

/// Configuration for GrillPOS SaaS implementation.
class RestaurantConfig {
  final String restaurantId;
  final String branchId;
  final String apiEndpoint;
  final String syncToken;
  final bool isCloudSyncEnabled;

  const RestaurantConfig({
    this.restaurantId = 'default',
    this.branchId = 'main',
    this.apiEndpoint = 'https://api.grillpos.com/v1',
    this.syncToken = '',
    this.isCloudSyncEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'restaurant_id': restaurantId,
      'branch_id': branchId,
      'api_endpoint': apiEndpoint,
      'sync_token': syncToken,
      'is_cloud_sync_enabled': isCloudSyncEnabled,
    };
  }

  factory RestaurantConfig.fromMap(Map<String, dynamic> map) {
    return RestaurantConfig(
      restaurantId: map['restaurant_id'] ?? 'default',
      branchId: map['branch_id'] ?? 'main',
      apiEndpoint: map['api_endpoint'] ?? 'https://api.grillpos.com/v1',
      syncToken: map['sync_token'] ?? '',
      isCloudSyncEnabled: map['is_cloud_sync_enabled'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory RestaurantConfig.fromJson(String source) =>
      RestaurantConfig.fromMap(json.decode(source));
}
