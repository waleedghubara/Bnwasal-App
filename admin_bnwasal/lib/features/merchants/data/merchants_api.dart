import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class MerchantsApi {
  final DioConsumer _dio;
  MerchantsApi(this._dio);

  Future<Map<String, dynamic>> getMerchants({
    int page = 1,
    int limit = 20,
    String search = '',
    String status = '',
  }) async {
    final response = await _dio.get(
      EndPoint.adminMerchants,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMerchantDetail(int id) async {
    final response = await _dio.get('${EndPoint.adminMerchants}/$id');
    return response as Map<String, dynamic>;
  }

  Future<void> deleteMerchant(int id) async {
    await _dio.delete('${EndPoint.adminMerchants}/$id');
  }

  Future<void> updateMerchantStatus(int id, String status) async {
    await _dio.patch('${EndPoint.adminMerchants}/$id/status', data: {'status': status});
  }

  Future<void> sendWarning(int id, String title, String body) async {
    await _dio.post('${EndPoint.adminMerchants}/$id/warning', data: {'title': title, 'body': body});
  }
}
