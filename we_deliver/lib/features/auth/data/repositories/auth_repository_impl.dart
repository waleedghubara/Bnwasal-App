import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/auth_response.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Map<String, dynamic>>> register({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final response = await remoteDataSource.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
        role: role,
        profileImage: profileImage,
        referralCode: referralCode,
      );
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.errorModel.errorMessage, code: e.errorModel.status));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final response = await remoteDataSource.verifyOtp(
        phone: phone,
        otpCode: otpCode,
      );
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.errorModel.errorMessage, code: e.errorModel.status));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> resendOtp({
    required String phone,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final message = await remoteDataSource.resendOtp(phone: phone);
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.errorModel.errorMessage, code: e.errorModel.status));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final response = await remoteDataSource.login(
        email: email,
        password: password,
      );
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.errorModel.errorMessage,
        code: e.errorModel.status,
        errorCode: e.errorModel.errorCode,
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDriverDocuments({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final response = await remoteDataSource.uploadDriverDocuments(
        nationalId: nationalId,
        nationalIdFront: nationalIdFront,
        nationalIdBack: nationalIdBack,
      );
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.errorModel.errorMessage, code: e.errorModel.status));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
