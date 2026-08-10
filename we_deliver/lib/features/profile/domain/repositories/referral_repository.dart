import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../data/models/referral_summary_model.dart';

abstract class ReferralRepository {
  Future<Either<Failure, ReferralSummaryModel>> getReferralSummary();
  Future<Either<Failure, String>> convertPoints();
}
