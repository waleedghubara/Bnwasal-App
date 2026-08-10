import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserEntity>> getProfile();
  Future<Either<Failure, UserEntity>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? storeName,
    String? city,
    double? latitude,
    double? longitude,
    File? profileImage,
    String? vehicleType,
  });
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
