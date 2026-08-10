import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class AddTripUseCase {
  final TripRepository repository;
  AddTripUseCase(this.repository);

  Future<Either<Failure, Trip>> call(Trip trip) async {
    return await repository.addTrip(trip);
  }
}

class UpdateTripUseCase {
  final TripRepository repository;
  UpdateTripUseCase(this.repository);

  Future<Either<Failure, Trip>> call(Trip trip) async {
    return await repository.updateTrip(trip);
  }
}

class DeleteTripUseCase {
  final TripRepository repository;
  DeleteTripUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteTrip(id);
  }
}
