import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_data_source.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource remoteDataSource;

  const AddressRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<SavedAddress>>> getAddresses() async {
    try {
      final list = await remoteDataSource.getAddresses();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SavedAddress>> addAddress(SavedAddress address) async {
    try {
      final result = await remoteDataSource.addAddress(address);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SavedAddress>> updateAddress(SavedAddress address) async {
    try {
      final result = await remoteDataSource.updateAddress(address);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAddress(String id) async {
    try {
      await remoteDataSource.deleteAddress(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
