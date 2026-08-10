import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/auth_response.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  }) {
    return repository.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      role: role,
      profileImage: profileImage,
      referralCode: referralCode,
    );
  }
}

class VerifyOtpUseCase {
  final AuthRepository repository;

  VerifyOtpUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String phone,
    required String otpCode,
  }) {
    return repository.verifyOtp(
      phone: phone,
      otpCode: otpCode,
    );
  }
}

class ResendOtpUseCase {
  final AuthRepository repository;

  ResendOtpUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String phone,
  }) {
    return repository.resendOtp(phone: phone);
  }
}

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String email,
    required String password,
  }) {
    return repository.login(
      email: email,
      password: password,
    );
  }
}

class UploadDriverDocumentsUseCase {
  final AuthRepository repository;

  UploadDriverDocumentsUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  }) {
    return repository.uploadDriverDocuments(
      nationalId: nationalId,
      nationalIdFront: nationalIdFront,
      nationalIdBack: nationalIdBack,
    );
  }
}
