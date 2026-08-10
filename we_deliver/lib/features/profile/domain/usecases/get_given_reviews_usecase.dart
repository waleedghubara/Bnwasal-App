import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../data/models/review_model.dart';
import '../repositories/review_repository.dart';

class GetGivenReviewsUseCase {
  final ReviewRepository repository;
  const GetGivenReviewsUseCase(this.repository);

  Future<Either<Failure, List<ReviewModel>>> call() => repository.getGivenReviews();
}
