import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/address_repository.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

class GetAddressesUseCase {
  final AddressRepository repository;

  GetAddressesUseCase(this.repository);

  Future<Either<Failure, List<SavedAddress>>> call() {
    return repository.getAddresses();
  }
}
