import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import '../models/review_model.dart';

abstract class ReviewRemoteDataSource {
  Future<ReceivedReviewsData> getMyReviews();
  Future<List<ReviewModel>> getGivenReviews();
  Future<void> createReview({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  });
  Future<UserRatingSummary> getUserRating(String userId);
  Future<ReviewStatusResult> checkReviewStatus(String shipmentId);
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  final Dio dio;
  ReviewRemoteDataSourceImpl({required this.dio});

  Future<Options> _authOptions() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<ReceivedReviewsData> getMyReviews() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}reviews',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return ReceivedReviewsData.fromJson(
        data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل التقييمات',
      );
    }
  }

  @override
  Future<List<ReviewModel>> getGivenReviews() async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}reviews/given',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List?;
      return list
              ?.map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل التقييمات الصادرة',
      );
    }
  }

  @override
  Future<void> createReview({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      final options = await _authOptions();
      final body = <String, dynamic>{
        'shipmentId': shipmentId,
        'rating': rating,
      };
      if (comment != null && comment.isNotEmpty) body['comment'] = comment;
      if (tags != null && tags.isNotEmpty) body['tags'] = tags;
      await dio.post(
        '${EndPoint.baseUrl}reviews',
        data: body,
        options: options,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تقديم التقييم',
      );
    }
  }

  @override
  Future<UserRatingSummary> getUserRating(String userId) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}reviews/user/$userId',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return UserRatingSummary.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل تحميل التقييم',
      );
    }
  }

  @override
  Future<ReviewStatusResult> checkReviewStatus(String shipmentId) async {
    try {
      final options = await _authOptions();
      final response = await dio.get(
        '${EndPoint.baseUrl}reviews/status/$shipmentId',
        options: options,
      );
      final data = response.data as Map<String, dynamic>;
      return ReviewStatusResult(
        hasReviewed: data['hasReviewed'] as bool? ?? false,
        existingRating: (data['review'] as Map<String, dynamic>?)?['rating'] as int?,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      throw ServerException(
        message: errorData['message'] as String? ?? 'فشل التحقق من التقييم',
      );
    }
  }
}

