import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../repositories/wallet_repository.dart';

/// Creates a Kashier payment session.
/// Returns a map with {sessionUrl, sessionId, amount, orderId}
class CreateDepositSessionUseCase {
  final WalletRepository repository;

  CreateDepositSessionUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(double amount) async {
    return await repository.createDepositSession(amount);
  }
}

/// Checks status of a Kashier session after WebView closes.
class CheckDepositSessionUseCase {
  final WalletRepository repository;

  CheckDepositSessionUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String sessionId) async {
    return await repository.checkDepositSession(sessionId);
  }
}
