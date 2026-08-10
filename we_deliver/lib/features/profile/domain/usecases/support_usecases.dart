import 'package:dartz/dartz.dart';
import 'package:we_deliver/features/profile/data/models/support_message_model.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/support_repository.dart';

class SubmitContactMessageUseCase {
  final SupportRepository repository;

  SubmitContactMessageUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    return await repository.submitContactMessage(
      name: name,
      email: email,
      subject: subject,
      message: message,
    );
  }
}

class GetSupportMessagesUseCase {
  final SupportRepository repository;

  GetSupportMessagesUseCase(this.repository);

  Future<Either<Failure, List<SupportMessageModel>>> call({int? afterId}) async {
    return await repository.getSupportMessages(afterId: afterId);
  }
}

class SendSupportMessageUseCase {
  final SupportRepository repository;

  SendSupportMessageUseCase(this.repository);

  Future<Either<Failure, SupportMessageModel>> call({
    required String text,
    String? imagePath,
  }) async {
    return await repository.sendSupportMessage(
      text: text,
      imagePath: imagePath,
    );
  }
}
