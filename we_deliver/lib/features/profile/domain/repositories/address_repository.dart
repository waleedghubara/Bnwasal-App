import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

abstract class AddressRepository {
  Future<Either<Failure, List<SavedAddress>>> getAddresses();
  Future<Either<Failure, SavedAddress>> addAddress(SavedAddress address);
  Future<Either<Failure, SavedAddress>> updateAddress(SavedAddress address);
  Future<Either<Failure, void>> deleteAddress(String id);
}
