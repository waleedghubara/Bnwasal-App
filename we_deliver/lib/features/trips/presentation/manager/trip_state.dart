import 'package:equatable/equatable.dart';
import '../../domain/entities/trip.dart';

abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {}

class TripLoading extends TripState {}

class TripActionLoading extends TripState {} // specific for button loading states

class TripLoaded extends TripState {
  final List<Trip> trips;

  const TripLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class TripError extends TripState {
  final String message;

  const TripError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripActionSuccess extends TripState {
  final String message;

  const TripActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
