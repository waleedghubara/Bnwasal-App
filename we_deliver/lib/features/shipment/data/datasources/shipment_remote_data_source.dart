import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../../domain/entities/shipment.dart';
import '../models/shipment_model.dart';
import '../models/message_model.dart';

abstract class ShipmentRemoteDataSource {
  Future<List<ShipmentModel>> getShipments({
    String? status,
    String? filter,
    String? query,
  });
  Future<ShipmentModel> addShipment(Shipment shipment);
  Future<void> updateShipment(Shipment shipment);
  Future<void> deleteShipment(String shipmentId);
  Future<void> updateShipmentStatus(
    String shipmentId,
    String status, {
    double? negotiatedPrice,
    double? latitude,
    double? longitude,
  });
  /// Called by captain to accept or reject an auto-assigned shipment.
  /// Uses PUT /:id/captain-response which properly clears captainId on reject
  /// and triggers auto-assignment for the next captain.
  Future<void> captainResponse(String shipmentId, String response); // 'accept' or 'reject'
  Future<ShipmentModel> getShipmentById(String shipmentId);
  Future<List<MessageModel>> getMessages(String shipmentId);
  Future<MessageModel> sendMessage(String shipmentId, String text);
  Future<void> updateFcmToken(String fcmToken);
}

class ShipmentRemoteDataSourceImpl implements ShipmentRemoteDataSource {
  final Dio dio;

  ShipmentRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<ShipmentModel>> getShipments({
    String? status,
    String? filter,
    String? query,
  }) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> queryParameters = {};
      if (status != null && status != 'الكل') queryParameters['status'] = status;
      if (filter != null) queryParameters['filter'] = filter;
      if (query != null && query.isNotEmpty) queryParameters['query'] = query;

      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getShipments}',
        queryParameters: queryParameters,
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((json) => ShipmentModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل الشحنات',
      );
    }
  }

  @override
  Future<ShipmentModel> addShipment(Shipment shipment) async {
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);

      // Construct FormData for multipart upload
      final Map<String, dynamic> formMap = {
        'title': shipment.title,
        'fromAddress': shipment.fromAddress,
        'toAddress': shipment.toAddress,
        'fromGovernorate': shipment.fromGovernorate,
        'fromArea': shipment.fromArea,
        'toGovernorate': shipment.toGovernorate,
        'toArea': shipment.toArea,
        'price': shipment.price.toString(),
        'weight': shipment.weight?.toString(),
        'notes': shipment.notes,
        'isFragile': shipment.isFragile.toString(),
        'isWithoutAdvance': shipment.isWithoutAdvance.toString(),
        if (shipment.couponCode != null) 'couponCode': shipment.couponCode,
        if (shipment.toLatitude != null) 'toLatitude': shipment.toLatitude.toString(),
        if (shipment.toLongitude != null) 'toLongitude': shipment.toLongitude.toString(),
        if (shipment.merchantLatitude != null) 'merchantLatitude': shipment.merchantLatitude.toString(),
        if (shipment.merchantLongitude != null) 'merchantLongitude': shipment.merchantLongitude.toString(),
      };

      // Add files
      if (shipment.images != null && shipment.images!.isNotEmpty) {
        final List<MultipartFile> multipartImages = [];
        for (final file in shipment.images!) {
          multipartImages.add(
            await MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
            ),
          );
        }
        formMap['images'] = multipartImages;
      }

      final formData = FormData.fromMap(formMap);

      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.createShipment}',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return ShipmentModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل إضافة الشحنة',
      );
    }
  }

  @override
  Future<void> updateShipment(Shipment shipment) async {
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);

      final Map<String, dynamic> formMap = {
        'title': shipment.title,
        'fromAddress': shipment.fromAddress,
        'toAddress': shipment.toAddress,
        'fromGovernorate': shipment.fromGovernorate,
        'fromArea': shipment.fromArea,
        'toGovernorate': shipment.toGovernorate,
        'toArea': shipment.toArea,
        'price': shipment.price.toString(),
        'weight': shipment.weight?.toString(),
        'notes': shipment.notes,
        'isFragile': shipment.isFragile.toString(),
        'isWithoutAdvance': shipment.isWithoutAdvance.toString(),
        if (shipment.toLatitude != null) 'toLatitude': shipment.toLatitude.toString(),
        if (shipment.toLongitude != null) 'toLongitude': shipment.toLongitude.toString(),
        if (shipment.merchantLatitude != null) 'merchantLatitude': shipment.merchantLatitude.toString(),
        if (shipment.merchantLongitude != null) 'merchantLongitude': shipment.merchantLongitude.toString(),
      };

      if (shipment.images != null && shipment.images!.isNotEmpty) {
        final List<MultipartFile> multipartImages = [];
        for (final file in shipment.images!) {
          multipartImages.add(
            await MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
            ),
          );
        }
        formMap['images'] = multipartImages;
      }

      final formData = FormData.fromMap(formMap);

      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/${shipment.id}',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تعديل الشحنة',
      );
    }
  }

  @override
  Future<void> deleteShipment(String shipmentId) async {
    try {
      final options = await _authOptions();
      await dio.delete(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/$shipmentId',
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل حذف الشحنة',
      );
    }
  }

  @override
  Future<void> updateShipmentStatus(
    String shipmentId,
    String status, {
    double? negotiatedPrice,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> bodyData = {
        'status': status,
      };
      if (negotiatedPrice != null) {
        bodyData['negotiatedPrice'] = negotiatedPrice;
      }
      if (latitude != null) {
        bodyData['startLatitude'] = latitude;
      }
      if (longitude != null) {
        bodyData['startLongitude'] = longitude;
      }
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/$shipmentId/status',
        data: bodyData,
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث حالة الشحنة',
      );
    }
  }

  @override
  Future<void> captainResponse(String shipmentId, String response) async {
    try {
      final options = await _authOptions();
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/$shipmentId/captain-response',
        data: {'response': response},
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث رد الكابتن',
      );
    }
  }

  @override
  Future<ShipmentModel> getShipmentById(String shipmentId) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/$shipmentId',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      return ShipmentModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل الشحنة',
      );
    }
  }

  @override
  Future<List<MessageModel>> getMessages(String shipmentId) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.shipmentMessages(shipmentId)}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((json) => MessageModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل الرسائل',
      );
    }
  }

  @override
  Future<MessageModel> sendMessage(String shipmentId, String text) async {
    try {
      final options = await _authOptions();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.shipmentMessages(shipmentId)}',
        data: {'text': text},
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      return MessageModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل إرسال الرسالة',
      );
    }
  }

  @override
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final options = await _authOptions();
      await dio.put(
        '${EndPoint.baseUrl}${EndPoint.updateFcmToken}',
        data: {'fcmToken': fcmToken},
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث رمز الإشعارات',
      );
    }
  }
}
