import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../data/models/referral_summary_model.dart';
import '../repositories/referral_repository.dart';

class GetReferralSummaryUseCase {
  final ReferralRepository repository;

  GetReferralSummaryUseCase(this.repository);

  Future<Either<Failure, ReferralSummaryModel>> call() async {
    return await repository.getReferralSummary();
  }
}

class ConvertPointsUseCase {
  final ReferralRepository repository;

  ConvertPointsUseCase(this.repository);

  Future<Either<Failure, String>> call() async {
    return await repository.convertPoints();
  }
}
