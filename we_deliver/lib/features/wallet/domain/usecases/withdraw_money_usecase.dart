import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/wallet_repository.dart';

class WithdrawMoneyUseCase {
  final WalletRepository repository;

  WithdrawMoneyUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    return await repository.withdrawMoney(
      amount: amount,
      paymentMethod: paymentMethod,
      name: name,
      phone: phone,
      walletProvider: walletProvider,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
    );
  }
}
