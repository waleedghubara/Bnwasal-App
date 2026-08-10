import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class AuthApi {
  final DioConsumer _dio;

  AuthApi(this._dio);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      EndPoint.adminLogin,
      data: {
        'email': email,
        'password': password,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(
      EndPoint.logout,
      data: {'refresh_token': refreshToken},
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get(EndPoint.getProfile);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? city,
  }) async {
    final data = <String, dynamic>{};
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (city != null) data['city'] = city;
    final response = await _dio.put(
      EndPoint.updateProfile,
      data: data,
      isFromData: true,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfileImage(String filePath) async {
    final formData = FormData.fromMap({
      'profileImage': await MultipartFile.fromFile(filePath, filename: 'profile.jpg'),
    });
    final response = await _dio.put(
      EndPoint.updateProfile,
      data: formData,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final response = await _dio.put(
      EndPoint.changePassword,
      data: {'currentPassword': oldPassword, 'newPassword': newPassword},
    );
    return response as Map<String, dynamic>;
  }
}
