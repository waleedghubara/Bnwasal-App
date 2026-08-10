import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/trip.dart';
import '../../domain/usecases/get_trips_usecase.dart';
import '../../domain/usecases/trip_usecases.dart';
import 'trip_state.dart';

class TripCubit extends Cubit<TripState> {
  final GetTripsUseCase getTripsUseCase;
  final AddTripUseCase addTripUseCase;
  final UpdateTripUseCase updateTripUseCase;
  final DeleteTripUseCase deleteTripUseCase;

  List<Trip> _trips = [];

  TripCubit({
    required this.getTripsUseCase,
    required this.addTripUseCase,
    required this.updateTripUseCase,
    required this.deleteTripUseCase,
  }) : super(TripInitial());

  List<Trip> get allTrips => _trips;

  Future<void> loadTrips() async {
    emit(TripLoading());
    final result = await getTripsUseCase();
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (trips) {
        _trips = List.from(trips);
        emit(TripLoaded(_trips));
      },
    );
  }

  Future<void> addTrip(Trip trip) async {
    emit(TripActionLoading());
    final result = await addTripUseCase(trip);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (newTrip) {
        _trips.insert(0, newTrip);
        emit(const TripActionSuccess('تم إضافة مسار الرحلة بنجاح'));
        emit(TripLoaded(List.from(_trips)));
      },
    );
  }

  Future<void> updateTrip(Trip trip) async {
    emit(TripActionLoading());
    final result = await updateTripUseCase(trip);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (updatedTrip) {
        final index = _trips.indexWhere((t) => t.id == trip.id);
        if (index != -1) {
          _trips[index] = updatedTrip;
        }
        emit(const TripActionSuccess('تم تعديل مسار الرحلة بنجاح'));
        emit(TripLoaded(List.from(_trips)));
      },
    );
  }

  Future<void> deleteTrip(String id) async {
    emit(TripActionLoading());
    final result = await deleteTripUseCase(id);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (_) {
        _trips.removeWhere((t) => t.id == id);
        emit(const TripActionSuccess('تم حذف مسار الرحلة بنجاح'));
        emit(TripLoaded(List.from(_trips)));
      },
    );
  }
}
