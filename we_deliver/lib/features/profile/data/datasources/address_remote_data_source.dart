import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

abstract class AddressRemoteDataSource {
  Future<List<SavedAddress>> getAddresses();
  Future<SavedAddress> addAddress(SavedAddress address);
  Future<SavedAddress> updateAddress(SavedAddress address);
  Future<void> deleteAddress(String id);
}

class AddressRemoteDataSourceImpl implements AddressRemoteDataSource {
  final Dio dio;

  AddressRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<SavedAddress>> getAddresses() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}addresses',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((json) => SavedAddress.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل العناوين المحفوظة',
      );
    }
  }

  @override
  Future<SavedAddress> addAddress(SavedAddress address) async {
    try {
      final options = await _authOptions();
      final response = await dio.post(
        '${EndPoint.baseUrl}addresses',
        data: address.toJson(),
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return SavedAddress.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل إضافة العنوان',
      );
    }
  }

  @override
  Future<SavedAddress> updateAddress(SavedAddress address) async {
    try {
      final options = await _authOptions();
      final response = await dio.put(
        '${EndPoint.baseUrl}addresses/${address.id}',
        data: address.toJson(),
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return SavedAddress.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحديث العنوان',
      );
    }
  }

  @override
  Future<void> deleteAddress(String id) async {
    try {
      final options = await _authOptions();
      await dio.delete(
        '${EndPoint.baseUrl}addresses/$id',
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل حذف العنوان',
      );
    }
  }
}
