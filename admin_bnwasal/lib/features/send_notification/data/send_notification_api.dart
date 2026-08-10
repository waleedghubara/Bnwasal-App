import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class SendNotificationApi {
  final DioConsumer _dio;
  SendNotificationApi(this._dio);

  Future<List<Map<String, dynamic>>> getTargetUsers(String targetType) async {
    final response = await _dio.get(
      'notifications/target-users',
      queryParameters: {'targetType': targetType},
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final users = data['users'] as List<dynamic>? ?? [];
    return users.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendBulk({
    required String targetType,
    String? specificUserId,
    List<String>? specificUserIds,
    required String title,
    required String body,
  }) async {
    final data = <String, dynamic>{
      'targetType': targetType,
      'title': title,
      'body': body,
    };
    if (specificUserIds != null && specificUserIds.isNotEmpty) {
      data['specificUserIds'] = specificUserIds;
    } else if (specificUserId != null) {
      data['specificUserId'] = specificUserId;
    }
    final response = await _dio.post(EndPoint.sendBulkNotification, data: data);
    return response as Map<String, dynamic>;
  }
}
