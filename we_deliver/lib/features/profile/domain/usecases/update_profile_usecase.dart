import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository repository;
  const UpdateProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    String? firstName,
    String? lastName,
    String? phone,
    String? storeName,
    String? city,
    double? latitude,
    double? longitude,
    File? profileImage,
    String? vehicleType,
  }) =>
      repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        storeName: storeName,
        city: city,
        latitude: latitude,
        longitude: longitude,
        profileImage: profileImage,
        vehicleType: vehicleType,
      );
}
