import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class EmployeesApi {
  final DioConsumer _dio;
  EmployeesApi(this._dio);

  Future<Map<String, dynamic>> getEmployees({int page = 1, int limit = 20, String search = ''}) async {
    final response = await _dio.get(
      EndPoint.adminEmployees,
      queryParameters: {
        'page': page, 'limit': limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployee(int id) async {
    final response = await _dio.get('${EndPoint.adminEmployees}/$id');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final response = await _dio.post(EndPoint.adminEmployees, data: data);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('${EndPoint.adminEmployees}/$id', data: data);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteEmployee(int id) async {
    final response = await _dio.delete('${EndPoint.adminEmployees}/$id');
    return response as Map<String, dynamic>;
  }
}
