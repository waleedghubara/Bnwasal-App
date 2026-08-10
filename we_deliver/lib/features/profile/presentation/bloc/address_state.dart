import 'package:equatable/equatable.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

abstract class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object?> get props => [];
}

class AddressInitial extends AddressState {
  const AddressInitial();
}

class AddressLoading extends AddressState {
  const AddressLoading();
}

class AddressLoaded extends AddressState {
  final List<SavedAddress> addresses;
  const AddressLoaded(this.addresses);

  @override
  List<Object?> get props => [addresses];
}

class AddressActionSuccess extends AddressState {
  final String message;
  const AddressActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AddressError extends AddressState {
  final String message;
  const AddressError(this.message);

  @override
  List<Object?> get props => [message];
}
