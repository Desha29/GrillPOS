import 'package:grill_pos/features/auth/data/repository/user_repository_imp.dart';
import 'package:grill_pos/features/auth/domain/repository/user_repository_int.dart';
import 'package:grill_pos/features/auth/presentation/cubit/user_cubit.dart';
import '../../features/menu/data/menu_repository.dart';
import '../../features/menu/presentation/cubit/menu_cubit.dart';
import '../../features/orders/data/orders_repository.dart';
import '../../features/orders/presentation/cubit/orders_cubit.dart';
import '../../features/pos/presentation/cubit/pos_cubit.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/reports/presentation/cubit/reports_cubit.dart';
import '../../features/tables/data/tables_repository.dart';
import '../../features/tables/presentation/cubit/tables_cubit.dart';
import 'package:get_it/get_it.dart';

import '../../features/settings/data/data_source/restaurant_info_data_source.dart';
import '../../features/settings/data/repository/settings_repository_imp.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../services/activity_logger.dart';

final getIt = GetIt.instance;

void setup() {
  // Core Services
  getIt.registerSingleton<ActivityLogger>(ActivityLogger());

  // GrillPOS repositories
  getIt.registerLazySingleton<MenuRepository>(() => MenuRepository());
  getIt.registerLazySingleton<TablesRepository>(() => TablesRepository());
  getIt.registerLazySingleton<OrdersRepository>(() => OrdersRepository());
  getIt.registerLazySingleton<ReportsRepository>(() => ReportsRepository());

  final userRepo = UserRepositoryImp();
  getIt.registerSingleton<UserRepositoryInt>(userRepo);

  getIt.registerSingleton<UserCubit>(UserCubit(
    userRepository: userRepo,
  ));
//
  final restaurantInfoRepo = RestaurantInfoRepository(
    dataSource: RestaurantInfoDataSource(),
  );
  getIt.registerSingleton<RestaurantInfoRepository>(restaurantInfoRepo);

  getIt.registerLazySingleton<SettingsCubit>(() => SettingsCubit(
        userCubit: getIt<UserCubit>(),
        restaurantRepository: restaurantInfoRepo,
      ));

  // GrillPOS Phase 3 Features
  getIt.registerFactory<MenuCubit>(() => MenuCubit(getIt<MenuRepository>()));
  getIt.registerFactory<TablesCubit>(
      () => TablesCubit(getIt<TablesRepository>()));
  getIt.registerFactory<OrdersCubit>(
      () => OrdersCubit(getIt<OrdersRepository>()));
  getIt.registerFactory<POSCubit>(
      () => POSCubit(getIt<MenuRepository>(), getIt<OrdersRepository>()));
  getIt.registerFactory<ReportsCubit>(
      () => ReportsCubit(getIt<ReportsRepository>()));
}
