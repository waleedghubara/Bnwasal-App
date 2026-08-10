import 'package:admin_bnwasal/core/api/dio_consumer.dart';

class UserMessagesApi {
  final DioConsumer _dio;
  UserMessagesApi(this._dio);

  Future<List<dynamic>> getUserMessages() async {
    final response = await _dio.get('support/contacts');
    final data = response['data'] as List? ?? [];
    return data;
  }

  Future<void> deleteUserMessage(int id) async {
    await _dio.delete('support/contacts/$id');
  }
}
