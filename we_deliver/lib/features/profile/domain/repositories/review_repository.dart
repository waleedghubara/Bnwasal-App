import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../data/models/review_model.dart';

abstract class ReviewRepository {
  Future<Either<Failure, ReceivedReviewsData>> getMyReviews();
  Future<Either<Failure, List<ReviewModel>>> getGivenReviews();
  Future<Either<Failure, void>> createReview({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  });
  Future<Either<Failure, UserRatingSummary>> getUserRating(String userId);
  Future<Either<Failure, ReviewStatusResult>> checkReviewStatus(String shipmentId);
}
