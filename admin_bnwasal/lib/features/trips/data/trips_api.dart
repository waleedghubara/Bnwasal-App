import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class TripsApi {
  final DioConsumer _dio;
  TripsApi(this._dio);

  Future<Map<String, dynamic>> getTrips({
    int page = 1, int limit = 20, String search = '',
    String date = '', String dateFrom = '', String dateTo = '', String status = '',
  }) async {
    final response = await _dio.get(
      EndPoint.adminTrips,
      queryParameters: {
        'page': page, 'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (date.isNotEmpty) 'date': date,
        if (dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo.isNotEmpty) 'dateTo': dateTo,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTodayTrips({String search = ''}) async {
    final response = await _dio.get(
      '${EndPoint.adminTrips}/today',
      queryParameters: {
        if (search.isNotEmpty) 'search': search,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTripsByCaptain(int captainId, {
    int page = 1, int limit = 20, String status = '', String date = '',
  }) async {
    final response = await _dio.get(
      '${EndPoint.adminTrips}/captain/$captainId',
      queryParameters: {
        'page': page, 'limit': limit,
        if (status.isNotEmpty) 'status': status,
        if (date.isNotEmpty) 'date': date,
      },
    );
    return response as Map<String, dynamic>;
  }
}
