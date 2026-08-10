import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/address_repository.dart';

class DeleteAddressUseCase {
  final AddressRepository repository;

  DeleteAddressUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteAddress(id);
  }
}
