import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../models/referral_summary_model.dart';

abstract class ReferralRemoteDataSource {
  Future<ReferralSummaryModel> getReferralSummary();
  Future<String> convertPoints();
}

class ReferralRemoteDataSourceImpl implements ReferralRemoteDataSource {
  final Dio dio;

  ReferralRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<ReferralSummaryModel> getReferralSummary() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.referralSummary}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        return ReferralSummaryModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تحميل بيانات الدعوة');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في الاتصال بالخادم');
    }
  }

  @override
  Future<String> convertPoints() async {
    try {
      final options = await _authOptions();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.convertPoints}',
        options: options,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 1) {
        return data['message'] ?? 'تم تحويل النقاط بنجاح';
      } else {
        throw ServerException(message: data['message'] ?? 'فشل تحويل النقاط');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(message: errorData['message'] ?? 'حدث خطأ في الاتصال بالخادم');
    }
  }
}
