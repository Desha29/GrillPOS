import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grill_pos/features/auth/presentation/cubit/user_cubit.dart';
import '../../data/models/restaurant_info_model.dart';
import '../../domain/repository/settings_repository_int.dart';
import 'settings_states.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/services/activity_logger.dart';
import '../../../../core/data/models/activity_log.dart';
import '../../../../core/security/permission_guard.dart';

class SettingsCubit extends Cubit<SettingsStates> {
  SettingsCubit({
    required this.userCubit,
    required this.restaurantRepository,
  }) : super(SettingsInitial()) {
    loadRestaurantInfo();
  }

  final UserCubit userCubit;
  final RestaurantInfoRepositoryInt restaurantRepository;

  static SettingsCubit get(context) => BlocProvider.of(context);

  RestaurantInfo? _currentRestaurantInfo;
  RestaurantInfo? get currentRestaurantInfo => _currentRestaurantInfo;

  Future<void> loadRestaurantInfo() async {
    emit(SettingsLoading());
    final result = await restaurantRepository.getRestaurantInfo();

    result.fold(
      (failure) => emit(RestaurantInfoUpdateFailure(failure.message)),
      (restaurantInfo) {
        _currentRestaurantInfo = restaurantInfo;
        emit(RestaurantInfoLoaded(restaurantInfo));
      },
    );
  }

  Future<void> updateRestaurantInfo(
      Map<String, String> newRestaurantInfoMap) async {
    emit(SettingsLoading());
    final newRestaurantInfo = RestaurantInfo.fromMap(newRestaurantInfoMap);
    final result =
        await restaurantRepository.saveRestaurantInfo(newRestaurantInfo);

    result.fold(
      (failure) {
        emit(RestaurantInfoUpdateFailure(failure.message));
        if (_currentRestaurantInfo != null) {
          emit(RestaurantInfoLoaded(_currentRestaurantInfo!));
        }
      },
      (_) async {
        _currentRestaurantInfo = newRestaurantInfo;

        await getIt<ActivityLogger>().logActivity(
          type: ActivityType.userUpdate,
          description: 'تحديث معلومات المطعم',
          userName: userCubit.currentUser.name,
        );

        emit(RestaurantInfoUpdateSuccess("تم حفظ معلومات المطعم بنجاح"));
        emit(RestaurantInfoLoaded(newRestaurantInfo));
      },
    );
  }

  String getCurrentUserName() {
    try {
      return userCubit.currentUser.name;
    } catch (e) {
      return 'غير معروف';
    }
  }

  String getCurrentUserType() {
    try {
      return userCubit.currentUser.userType.name;
    } catch (e) {
      return 'cashier';
    }
  }

  bool isAdmin() {
    try {
      return PermissionGuard.can(
        userCubit.currentUser,
        AppPermission.manageSettings,
      );
    } catch (e) {
      return false;
    }
  }
}
