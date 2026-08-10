import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/wallet_entity.dart';
import '../entities/transaction_entity.dart';

abstract class WalletRepository {
  Future<Either<Failure, WalletEntity>> getWalletData();

  /// Creates a Kashier payment session. Returns {sessionUrl, sessionId, amount, orderId}
  Future<Either<Failure, Map<String, dynamic>>> createDepositSession(
    double amount,
  );

  /// Checks status of a Kashier session after WebView closes.
  /// Returns {paymentStatus, newBalance}
  Future<Either<Failure, Map<String, dynamic>>> checkDepositSession(
    String sessionId,
  );

  Future<Either<Failure, List<TransactionEntity>>> getTransactions({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, void>> withdrawMoney({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  });
}
