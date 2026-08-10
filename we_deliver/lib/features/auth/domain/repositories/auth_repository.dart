import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/auth_response.dart';

abstract class AuthRepository {
  Future<Either<Failure, Map<String, dynamic>>> register({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  });

  Future<Either<Failure, AuthResponse>> verifyOtp({
    required String phone,
    required String otpCode,
  });

  Future<Either<Failure, String>> resendOtp({
    required String phone,
  });

  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, String>> uploadDriverDocuments({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  });
}
