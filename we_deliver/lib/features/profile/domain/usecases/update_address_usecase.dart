import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/address_repository.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

class UpdateAddressUseCase {
  final AddressRepository repository;

  UpdateAddressUseCase(this.repository);

  Future<Either<Failure, SavedAddress>> call(SavedAddress address) {
    return repository.updateAddress(address);
  }
}
