import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../../domain/entities/order.dart';
import '../models/order_model.dart';

abstract class OrderRemoteDataSource {
  Future<List<OrderModel>> getOrders({
    String? filter,
    String? status,
  });
  Future<OrderModel> createOrder(OrderEntity order);
  Future<void> updateOrder(OrderEntity order);
  Future<void> deleteOrder(String orderId);
  Future<OrderModel> getOrderById(String orderId);
  Future<void> updateOrderStatus(String orderId, String status, {double? latitude, double? longitude});
  /// Captain responds to an auto-assigned order using the dedicated endpoint
  Future<void> captainResponse(String orderId, String response); // 'accept' or 'reject'
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final Dio dio;

  OrderRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<OrderModel>> getOrders({
    String? filter,
    String? status,
  }) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> queryParameters = {};
      if (filter != null) queryParameters['filter'] = filter;
      if (status != null && status != 'الكل') queryParameters['status'] = status;

      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getOrders}',
        queryParameters: queryParameters,
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((json) => OrderModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل الطلبات',
      );
    }
  }

  @override
  Future<OrderModel> createOrder(OrderEntity order) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> bodyData = {
        'details': order.details,
        'storeDescription': order.storeDescription,
        'notes': order.notes,
        'deliveryAddress': order.deliveryAddress,
        'clientName': order.clientName,
        'phone': order.phone,
        'orderPrice': order.orderPrice,
        'deliveryFee': order.deliveryFee,
        if (order.couponCode != null) 'couponCode': order.couponCode,
        if (order.latitude != null) 'latitude': order.latitude,
        if (order.longitude != null) 'longitude': order.longitude,
      };

      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.createOrder}',
        data: bodyData,
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      return OrderModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل إضافة الطلب',
      );
    }
  }

  @override
  Future<void> updateOrder(OrderEntity order) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> bodyData = {
        'details': order.details,
        'storeDescription': order.storeDescription,
        'notes': order.notes,
        'deliveryAddress': order.deliveryAddress,
        'clientName': order.clientName,
        'phone': order.phone,
        'orderPrice': order.orderPrice,
        'deliveryFee': order.deliveryFee,
        if (order.latitude != null) 'latitude': order.latitude,
        if (order.longitude != null) 'longitude': order.longitude,
      };

      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.getOrders}/${order.id}',
        data: bodyData,
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تعديل الطلب',
      );
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    try {
      final options = await _authOptions();
      await dio.delete(
        '${EndPoint.baseUrl}${EndPoint.getOrders}/$orderId',
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل حذف الطلب',
      );
    }
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getOrderById(orderId)}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      return OrderModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل جلب تفاصيل الطلب',
      );
    }
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> bodyData = {
        'status': status,
      };
      if (latitude != null) {
        bodyData['latitude'] = latitude;
      }
      if (longitude != null) {
        bodyData['longitude'] = longitude;
      }
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.updateOrderStatus(orderId)}',
        data: bodyData,
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث حالة الطلب',
      );
    }
  }

  @override
  Future<void> captainResponse(String orderId, String response) async {
    try {
      final options = await _authOptions();
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.getOrders}/$orderId/captain-response',
        data: {'response': response},
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث رد الكابتن على الطلب',
      );
    }
  }
}
