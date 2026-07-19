import 'package:dartz/dartz.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repository/settings_repository_int.dart';
import '../data_source/restaurant_info_data_source.dart';
import '../models/restaurant_info_model.dart';

class RestaurantInfoRepository implements RestaurantInfoRepositoryInt {
  final RestaurantInfoDataSource dataSource;

  RestaurantInfoRepository({required this.dataSource});

  @override
  Future<Either<Failure, RestaurantInfo>> getRestaurantInfo() async {
    try {
      final restaurantInfo = await dataSource.getRestaurantInfo();
      if (restaurantInfo != null) {
        return Right(restaurantInfo);
      } else {
        final defaultRestaurant = dataSource.getDefaultRestaurantInfo();
        await dataSource.saveRestaurantInfo(defaultRestaurant);
        return Right(defaultRestaurant);
      }
    } catch (e) {
      return Left(CacheFailure('فشل في جلب معلومات المطعم: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveRestaurantInfo(
      RestaurantInfo restaurantInfo) async {
    try {
      await dataSource.saveRestaurantInfo(restaurantInfo);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('فشل في حفظ معلومات المطعم: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteRestaurantInfo() async {
    try {
      await dataSource.deleteRestaurantInfo();
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('فشل في حذف معلومات المطعم: ${e.toString()}'));
    }
  }
}
