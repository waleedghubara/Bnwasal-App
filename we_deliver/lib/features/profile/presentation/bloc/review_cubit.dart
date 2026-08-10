import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/usecases/get_my_reviews_usecase.dart';
import '../../domain/usecases/get_given_reviews_usecase.dart';
import '../../domain/usecases/create_review_usecase.dart';
import '../../data/models/review_model.dart';
import 'review_state.dart';

class ReviewCubit extends Cubit<ReviewState> {
  final ReviewRepository _repository;
  final GetMyReviewsUseCase _getMyReviews;
  final GetGivenReviewsUseCase _getGivenReviews;
  final CreateReviewUseCase _createReview;

  ReviewCubit({
    required ReviewRepository repository,
    required GetMyReviewsUseCase getMyReviews,
    required GetGivenReviewsUseCase getGivenReviews,
    required CreateReviewUseCase createReview,
  })  : _repository = repository,
        _getMyReviews = getMyReviews,
        _getGivenReviews = getGivenReviews,
        _createReview = createReview,
        super(const ReviewInitial());

  Future<void> loadReviews() async {
    emit(const ReviewLoading());
    
    final receivedResult = await _getMyReviews();
    final givenResult = await _getGivenReviews();

    receivedResult.fold(
      (failure) => emit(ReviewError(failure.message)),
      (receivedData) {
        givenResult.fold(
          (failure) => emit(ReviewError(failure.message)),
          (givenList) => emit(ReviewLoaded(
            receivedReviewsData: receivedData,
            givenReviews: givenList,
          )),
        );
      },
    );
  }

  Future<void> submitReview({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    emit(const ReviewLoading());
    final result = await _createReview(
      shipmentId: shipmentId,
      rating: rating,
      comment: comment,
      tags: tags,
    );
    result.fold(
      (failure) => emit(ReviewError(failure.message)),
      (_) => emit(const ReviewSubmitSuccess('تم حفظ التقييم بنجاح')),
    );
  }

  /// Fetch the average rating for a specific user (driver/merchant).
  /// Returns null on failure so screens can fall back gracefully.
  Future<UserRatingSummary?> getUserRating(String userId) async {
    final result = await _repository.getUserRating(userId);
    return result.fold((_) => null, (summary) => summary);
  }

  /// Check whether the current user has already reviewed a shipment.
  Future<ReviewStatusResult?> checkReviewStatus(String shipmentId) async {
    final result = await _repository.checkReviewStatus(shipmentId);
    return result.fold((_) => null, (status) => status);
  }
}

