import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class NotificationsApi {
  final DioConsumer _dio;
  NotificationsApi(this._dio);

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await _dio.get(EndPoint.getNotifications);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAsRead(String id) async {
    final response = await _dio.put(EndPoint.markNotificationRead(id));
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAllAsRead() async {
    final response = await _dio.put(EndPoint.markAllNotificationsRead);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteNotification(String id) async {
    final response = await _dio.delete(EndPoint.deleteNotification(id));
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clearAll() async {
    final response = await _dio.delete(EndPoint.clearAllNotifications);
    return response as Map<String, dynamic>;
  }
}
