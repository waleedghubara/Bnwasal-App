import 'dart:io';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../models/profile_user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileUserModel> getProfile();
  Future<ProfileUserModel> updateProfile({
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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;
  ProfileRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<ProfileUserModel> getProfile() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getProfile}',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return ProfileUserModel.fromJson(
        data['data']['user'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل البيانات',
      );
    }
  }

  @override
  Future<ProfileUserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? storeName,
    String? city,
    double? latitude,
    double? longitude,
    File? profileImage,
    String? vehicleType,
  }) async {
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);

      final Map<String, dynamic> dataMap = {};
      if (firstName != null) dataMap['firstName'] = firstName;
      if (lastName != null) dataMap['lastName'] = lastName;
      if (phone != null) dataMap['phone'] = phone;
      if (storeName != null) dataMap['storeName'] = storeName;
      if (city != null) dataMap['city'] = city;
      if (latitude != null) dataMap['latitude'] = latitude;
      if (longitude != null) dataMap['longitude'] = longitude;
      if (vehicleType != null) dataMap['vehicleType'] = vehicleType;
      if (profileImage != null) {
        dataMap['profileImage'] = await MultipartFile.fromFile(profileImage.path);
      }

      final formData = FormData.fromMap(dataMap);

      final response = await dio.put(
        '${EndPoint.baseUrl}${EndPoint.updateProfile}',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return ProfileUserModel.fromJson(
        data['data']['user'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث البيانات',
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.changePassword}',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تغيير كلمة المرور',
      );
    }
  }
}
