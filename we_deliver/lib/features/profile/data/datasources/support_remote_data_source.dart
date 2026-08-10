import 'package:dio/dio.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/support_message_model.dart';

abstract class SupportRemoteDataSource {
  Future<void> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  });
  Future<List<SupportMessageModel>> getSupportMessages({int? afterId});
  Future<SupportMessageModel> sendSupportMessage({
    required String text,
    String? imagePath,
  });
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  final Dio dio;

  SupportRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<void> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      final options = await _authOptions();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.contactUs}',
        data: {
          'name': name,
          'email': email,
          'subject': subject,
          'message': message,
        },
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1) {
        throw ServerException(message: data['message'] ?? 'فشل إرسال الرسالة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في الاتصال بالخادم');
    }
  }

  @override
  Future<List<SupportMessageModel>> getSupportMessages({int? afterId}) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.supportChat}',
        queryParameters: afterId != null ? {'afterId': afterId} : null,
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        final list = data['data'] as List?;
        return list?.map((item) => SupportMessageModel.fromJson(item)).toList() ?? [];
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تحميل رسائل الدعم');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في الاتصال بالخادم');
    }
  }

  @override
  Future<SupportMessageModel> sendSupportMessage({
    required String text,
    String? imagePath,
  }) async {
    try {
      final options = await _authOptions();
      final Map<String, dynamic> dataMap = {
        'text': text,
      };

      if (imagePath != null) {
        dataMap['image'] = await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        );
      }

      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.supportChat}',
        data: FormData.fromMap(dataMap),
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        return SupportMessageModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw ServerException(message: data['message'] ?? 'فشل إرسال الرسالة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في الاتصال بالخادم');
    }
  }
}
