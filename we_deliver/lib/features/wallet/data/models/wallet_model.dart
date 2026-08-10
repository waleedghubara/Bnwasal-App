import '../../domain/entities/wallet_entity.dart';
import 'transaction_model.dart';

class WalletModel extends WalletEntity {
  const WalletModel({
    required super.currentBalance,
    required super.availableBalance,
    required super.pendingBalance,
    super.totalBalance = 0.0,
    super.captainEarnings = 0.0,
    super.duePlatformFees = 0.0,
    required super.recentTransactions,
    super.pendingWithdrawal,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final curBal = (json['current_balance'] ?? 0).toDouble();
    var earn = (json['captain_earnings'] ?? 0).toDouble();
    var fees = (json['due_platform_fees'] ?? 0).toDouble();

    // Fallback: If earn & fees are 0 but curBal > 0, apply 80% Captain / 20% Platform rule
    if (earn == 0 && fees == 0 && curBal > 0) {
      earn = double.parse((curBal * 0.80).toStringAsFixed(2));
      fees = double.parse((curBal * 0.20).toStringAsFixed(2));
    }

    final total = json['total_balance'] != null && (json['total_balance'] as num).toDouble() > 0
        ? (json['total_balance'] as num).toDouble()
        : (curBal > 0 ? curBal : earn + fees);

    return WalletModel(
      currentBalance: curBal,
      availableBalance: (json['available_balance'] ?? (curBal - fees > 0 ? curBal - fees : 0)).toDouble(),
      pendingBalance: (json['pending_balance'] ?? 0).toDouble(),
      totalBalance: total,
      captainEarnings: earn,
      duePlatformFees: fees,
      recentTransactions: (json['recent_transactions'] as List?)
              ?.map((e) => TransactionModel.fromJson(e))
              .toList() ??
          [],
      pendingWithdrawal: json['pendingWithdrawal'] != null
          ? TransactionModel.fromJson(json['pendingWithdrawal'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_balance': currentBalance,
      'available_balance': availableBalance,
      'pending_balance': pendingBalance,
      'total_balance': totalBalance,
      'captain_earnings': captainEarnings,
      'due_platform_fees': duePlatformFees,
      'pendingWithdrawal': pendingWithdrawal != null
          ? (pendingWithdrawal as TransactionModel).toJson()
          : null,
      'recent_transactions':
          recentTransactions.map((e) => (e as TransactionModel).toJson()).toList(),
    };
  }
}
