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

import '../../features/settings/data/data_source/store_info_data_source.dart';
import '../../features/settings/data/repository/settings_repository_imp.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/sessions/data/repositories/session_repository_impl.dart';
import '../../core/services/activity_logger.dart';
import '../../core/session/session_manager.dart';

final getIt = GetIt.instance;

void setup() {
  // Core Services
  getIt.registerSingleton<ActivityLogger>(ActivityLogger());

  // Repositories
  getIt.registerSingleton<SessionRepositoryImpl>(SessionRepositoryImpl());

  // GrillPOS repositories
  getIt.registerLazySingleton<MenuRepository>(() => MenuRepository());
  getIt.registerLazySingleton<TablesRepository>(() => TablesRepository());
  getIt.registerLazySingleton<OrdersRepository>(() => OrdersRepository());
  getIt.registerLazySingleton<ReportsRepository>(() => ReportsRepository());

  // Session Manager (wraps SessionRepositoryImpl)
  final sessionManager = SessionManager();
  sessionManager.initialize(getIt<SessionRepositoryImpl>());
  getIt.registerSingleton<SessionManager>(sessionManager);

  final userRepo = UserRepositoryImp();
  getIt.registerSingleton<UserRepositoryInt>(userRepo);

  getIt.registerSingleton<UserCubit>(UserCubit(
      userRepository: userRepo,
      sessionRepository: getIt<SessionRepositoryImpl>()));

  final storeInfoRepo = StoreInfoRepository(
    dataSource: StoreInfoDataSource(),
  );
  getIt.registerSingleton<StoreInfoRepository>(storeInfoRepo);

  getIt.registerLazySingleton<SettingsCubit>(() => SettingsCubit(
        userCubit: getIt<UserCubit>(),
        storeRepository: storeInfoRepo,
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
