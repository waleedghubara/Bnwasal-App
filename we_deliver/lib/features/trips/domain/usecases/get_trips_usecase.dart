import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';

import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class GetTripsUseCase {
  final TripRepository repository;

  GetTripsUseCase(this.repository);

  Future<Either<Failure, List<Trip>>> call() async {
    return await repository.getTrips();
  }
}
