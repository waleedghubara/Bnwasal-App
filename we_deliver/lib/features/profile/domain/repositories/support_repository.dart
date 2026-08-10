import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../data/models/support_message_model.dart';

abstract class SupportRepository {
  Future<Either<Failure, void>> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  });

  Future<Either<Failure, List<SupportMessageModel>>> getSupportMessages({int? afterId});

  Future<Either<Failure, SupportMessageModel>> sendSupportMessage({
    required String text,
    String? imagePath,
  });
}
