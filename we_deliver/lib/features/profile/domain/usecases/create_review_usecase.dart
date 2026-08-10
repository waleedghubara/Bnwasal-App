import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/review_repository.dart';

class CreateReviewUseCase {
  final ReviewRepository repository;
  const CreateReviewUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) {
    return repository.createReview(
      shipmentId: shipmentId,
      rating: rating,
      comment: comment,
      tags: tags,
    );
  }
}
