import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/trip.dart';

abstract class TripRepository {
  Future<Either<Failure, List<Trip>>> getTrips();
  Future<Either<Failure, Trip>> addTrip(Trip trip);
  Future<Either<Failure, Trip>> updateTrip(Trip trip);
  Future<Either<Failure, void>> deleteTrip(String id);
}
