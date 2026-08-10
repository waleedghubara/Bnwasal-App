import 'package:equatable/equatable.dart';
import 'transaction_entity.dart';

class WalletEntity extends Equatable {
  final double currentBalance;
  final double availableBalance;
  final double pendingBalance;
  final double totalBalance;
  final double captainEarnings;
  final double duePlatformFees;
  final List<TransactionEntity> recentTransactions;
  final TransactionEntity? pendingWithdrawal;

  const WalletEntity({
    required this.currentBalance,
    required this.availableBalance,
    required this.pendingBalance,
    this.totalBalance = 0.0,
    this.captainEarnings = 0.0,
    this.duePlatformFees = 0.0,
    required this.recentTransactions,
    this.pendingWithdrawal,
  });

  @override
  List<Object?> get props => [
        currentBalance,
        availableBalance,
        pendingBalance,
        totalBalance,
        captainEarnings,
        duePlatformFees,
        recentTransactions,
        pendingWithdrawal,
      ];
}
