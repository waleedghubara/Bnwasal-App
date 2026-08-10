import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../data/models/review_model.dart';
import '../repositories/review_repository.dart';

class GetMyReviewsUseCase {
  final ReviewRepository repository;
  const GetMyReviewsUseCase(this.repository);

  Future<Either<Failure, ReceivedReviewsData>> call() => repository.getMyReviews();
}
