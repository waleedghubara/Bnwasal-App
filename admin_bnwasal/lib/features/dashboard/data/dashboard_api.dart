import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class DashboardApi {
  final DioConsumer _dio;
  DashboardApi(this._dio);

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _dio.get(EndPoint.adminDashboard);
    return response as Map<String, dynamic>;
  }
}
