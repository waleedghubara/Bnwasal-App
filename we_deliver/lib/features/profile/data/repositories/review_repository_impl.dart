import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/exceptions.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_data_source.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource remoteDataSource;

  const ReviewRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ReceivedReviewsData>> getMyReviews() async {
    try {
      final data = await remoteDataSource.getMyReviews();
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReviewModel>>> getGivenReviews() async {
    try {
      final list = await remoteDataSource.getGivenReviews();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createReview({
    required String shipmentId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      await remoteDataSource.createReview(
        shipmentId: shipmentId,
        rating: rating,
        comment: comment,
        tags: tags,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserRatingSummary>> getUserRating(String userId) async {
    try {
      final summary = await remoteDataSource.getUserRating(userId);
      return Right(summary);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReviewStatusResult>> checkReviewStatus(String shipmentId) async {
    try {
      final result = await remoteDataSource.checkReviewStatus(shipmentId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}

