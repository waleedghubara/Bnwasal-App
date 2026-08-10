import 'package:equatable/equatable.dart';
import '../../data/models/review_model.dart';

abstract class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {
  const ReviewInitial();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

class ReviewLoaded extends ReviewState {
  final ReceivedReviewsData receivedReviewsData;
  final List<ReviewModel> givenReviews;

  const ReviewLoaded({
    required this.receivedReviewsData,
    required this.givenReviews,
  });

  @override
  List<Object?> get props => [receivedReviewsData, givenReviews];
}

class ReviewSubmitSuccess extends ReviewState {
  final String message;
  const ReviewSubmitSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ReviewError extends ReviewState {
  final String message;
  const ReviewError(this.message);

  @override
  List<Object?> get props => [message];
}
