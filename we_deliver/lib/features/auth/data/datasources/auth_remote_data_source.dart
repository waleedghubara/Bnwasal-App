import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/api/api_consumer.dart';
import '../../../../core/api/end_point.dart';
import '../models/auth_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  });

  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otpCode,
  });

  Future<String> resendOtp({
    required String phone,
  });

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<String> uploadDriverDocuments({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiConsumer api;

  AuthRemoteDataSourceImpl({required this.api});

  @override
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  }) async {
    final Map<String, dynamic> data = {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'password': password,
      'role': role,
    };

    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }

    if (referralCode != null && referralCode.isNotEmpty) {
      data['referredByCode'] = referralCode;
    }

    if (profileImage != null) {
      data['profileImage'] = await MultipartFile.fromFile(
        profileImage.path,
        filename: profileImage.path.split('/').last,
      );
    }

    final response = await api.post(
      EndPoint.register,
      data: data,
      isFromData: profileImage != null,
    );

    return response as Map<String, dynamic>;
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    final response = await api.post(
      EndPoint.verifyOtp,
      data: {
        'phone': phone,
        'otp_code': otpCode,
      },
    );

    return AuthResponseModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<String> resendOtp({
    required String phone,
  }) async {
    final response = await api.post(
      EndPoint.resendOtp,
      data: {
        'phone': phone,
      },
    );

    return response['message'] as String;
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await api.post(
      EndPoint.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthResponseModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<String> uploadDriverDocuments({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  }) async {
    final formDataMap = {
      'nationalId': nationalId,
      'nationalIdFront': await MultipartFile.fromFile(
        nationalIdFront.path,
        filename: nationalIdFront.path.split('/').last,
      ),
      'nationalIdBack': await MultipartFile.fromFile(
        nationalIdBack.path,
        filename: nationalIdBack.path.split('/').last,
      ),
    };

    final response = await api.post(
      EndPoint.uploadDriverDocuments,
      data: formDataMap,
      isFromData: true,
    );

    return response['message'] as String;
  }
}
