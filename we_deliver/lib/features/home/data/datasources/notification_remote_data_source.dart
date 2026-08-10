import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> deleteNotification(String id);
  Future<void> clearAllNotifications();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio dio;

  NotificationRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getNotifications}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        final list = data['data'] as List;
        return list
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تحميل الإشعارات');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الإشعارات');
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      final options = await _authOptions();
      final response = await dio.put(
        '${EndPoint.baseUrl}${EndPoint.markNotificationRead(id)}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل تحديث حالة الإشعار');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الإشعارات');
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      final options = await _authOptions();
      final response = await dio.put(
        '${EndPoint.baseUrl}${EndPoint.markAllNotificationsRead}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل تحديث جميع الإشعارات');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الإشعارات');
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    try {
      final options = await _authOptions();
      final response = await dio.delete(
        '${EndPoint.baseUrl}${EndPoint.deleteNotification(id)}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل حذف الإشعار');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الإشعارات');
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    try {
      final options = await _authOptions();
      final response = await dio.delete(
        '${EndPoint.baseUrl}${EndPoint.clearAllNotifications}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل مسح الإشعارات');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الإشعارات');
    }
  }
}
