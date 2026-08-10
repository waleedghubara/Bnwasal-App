import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/profile_repository.dart';

class ChangePasswordUseCase {
  final ProfileRepository repository;
  const ChangePasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String currentPassword,
    required String newPassword,
  }) =>
      repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}
