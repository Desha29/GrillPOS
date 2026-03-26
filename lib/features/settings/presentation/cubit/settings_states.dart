// settings_states.dart

import '../../data/models/restaurant_info_model.dart';

abstract class SettingsStates {}

class SettingsInitial extends SettingsStates {}

class SettingsLoading extends SettingsStates {}

class RestaurantInfoLoaded extends SettingsStates {
  final RestaurantInfo restaurantInfo;
  RestaurantInfoLoaded(this.restaurantInfo);
}

class RestaurantInfoUpdateSuccess extends SettingsStates {
  final String message;
  RestaurantInfoUpdateSuccess(this.message);
}

class RestaurantInfoUpdateFailure extends SettingsStates {
  final String message;
  RestaurantInfoUpdateFailure(this.message);
}
