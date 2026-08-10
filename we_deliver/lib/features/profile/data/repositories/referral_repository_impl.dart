import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/referral_repository.dart';
import '../datasources/referral_remote_data_source.dart';
import '../models/referral_summary_model.dart';

class ReferralRepositoryImpl implements ReferralRepository {
  final ReferralRemoteDataSource remoteDataSource;

  ReferralRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ReferralSummaryModel>> getReferralSummary() async {
    try {
      final summary = await remoteDataSource.getReferralSummary();
      return Right(summary);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> convertPoints() async {
    try {
      final message = await remoteDataSource.convertPoints();
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
