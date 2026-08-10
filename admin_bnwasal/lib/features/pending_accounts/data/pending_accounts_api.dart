import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class PendingAccountsApi {
  final DioConsumer _dio;
  PendingAccountsApi(this._dio);

  Future<Map<String, dynamic>> getPendingAccounts({int page = 1, int limit = 20, String role = ''}) async {
    final response = await _dio.get(
      EndPoint.adminPendingAccounts,
      queryParameters: {'page': page, 'limit': limit, if (role.isNotEmpty) 'role': role},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPendingAccountDetail(int id) async {
    final response = await _dio.get('${EndPoint.adminPendingAccounts}/$id');
    return response as Map<String, dynamic>;
  }

  Future<void> approveAccount(int id) async {
    await _dio.patch('${EndPoint.adminPendingAccounts}/$id/approve');
  }

  Future<void> rejectAccount(int id) async {
    await _dio.patch('${EndPoint.adminPendingAccounts}/$id/reject');
  }
}
