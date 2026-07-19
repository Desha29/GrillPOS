class RestaurantConfig {
  final String restaurantId;
  final String branchId;
  final String subscriptionTier;
  final Map<String, bool> features;

  const RestaurantConfig({
    required this.restaurantId,
    required this.branchId,
    this.subscriptionTier = 'starter',
    this.features = const {},
  });

  factory RestaurantConfig.fromMap(Map<String, dynamic> map) {
    final rawFeatures =
        (map['features'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RestaurantConfig(
      restaurantId: (map['restaurant_id'] as String?) ?? 'default',
      branchId: (map['branch_id'] as String?) ?? 'main',
      subscriptionTier: (map['subscription_tier'] as String?) ?? 'starter',
      features: rawFeatures.map((k, v) => MapEntry(k, v == true || v == 1)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurant_id': restaurantId,
      'branch_id': branchId,
      'subscription_tier': subscriptionTier,
      'features': features,
    };
  }

  RestaurantConfig copyWith({
    String? restaurantId,
    String? branchId,
    String? subscriptionTier,
    Map<String, bool>? features,
  }) {
    return RestaurantConfig(
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      features: features ?? this.features,
    );
  }
}
