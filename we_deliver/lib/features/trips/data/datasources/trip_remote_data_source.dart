import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../../domain/entities/trip.dart';
import '../models/trip_model.dart';

abstract class TripRemoteDataSource {
  Future<List<TripModel>> getTrips();
  Future<TripModel> addTrip(Trip trip);
  Future<TripModel> updateTrip(Trip trip);
  Future<void> deleteTrip(String id);
}

class TripRemoteDataSourceImpl implements TripRemoteDataSource {
  final Dio dio;

  TripRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<TripModel>> getTrips() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getTrips}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        final list = data['data'] as List;
        return list
            .map((json) => TripModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تحميل مسارات الرحلات');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الرحلات');
    }
  }

  @override
  Future<TripModel> addTrip(Trip trip) async {
    try {
      final options = await _authOptions();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.createTrip}',
        data: {
          'from': trip.from,
          'to': trip.to,
          'fromCity': trip.fromCity,
          'toCity': trip.toCity,
          'passingCities': trip.passingCities,
          'departureTime': trip.departureTime,
          'arrivalTime': trip.arrivalTime,
          'date': trip.date.toIso8601String(),
          'time': trip.time,
          'price': trip.price,
          'distance': trip.distance,
        },
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        return TripModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw ServerException(message: data['message'] ?? 'فشل إضافة مسار الرحلة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الرحلات');
    }
  }

  @override
  Future<TripModel> updateTrip(Trip trip) async {
    try {
      final options = await _authOptions();
      final response = await dio.put(
        '${EndPoint.baseUrl}${EndPoint.updateTrip(trip.id)}',
        data: {
          'from': trip.from,
          'to': trip.to,
          'fromCity': trip.fromCity,
          'toCity': trip.toCity,
          'passingCities': trip.passingCities,
          'departureTime': trip.departureTime,
          'arrivalTime': trip.arrivalTime,
          'date': trip.date.toIso8601String(),
          'time': trip.time,
          'status': trip.status == TripStatus.ongoing ? 'in_progress' : trip.status.name,
          'price': trip.price,
          'distance': trip.distance,
        },
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        return TripModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تعديل مسار الرحلة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الرحلات');
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    try {
      final options = await _authOptions();
      final response = await dio.delete(
        '${EndPoint.baseUrl}${EndPoint.deleteTrip(id)}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل حذف مسار الرحلة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في خادم الرحلات');
    }
  }
}
