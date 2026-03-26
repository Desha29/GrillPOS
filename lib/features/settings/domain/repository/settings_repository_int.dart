import 'package:dartz/dartz.dart';


import '../../../../core/error/failure.dart';
import '../../data/models/restaurant_info_model.dart';

abstract class RestaurantInfoRepositoryInt {
  Future<Either<Failure, RestaurantInfo>> getRestaurantInfo();
  Future<Either<Failure, Unit>> saveRestaurantInfo(RestaurantInfo restaurantInfo);
  Future<Either<Failure, Unit>> deleteRestaurantInfo();
}
