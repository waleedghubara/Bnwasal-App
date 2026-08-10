import 'package:equatable/equatable.dart';
import '../../domain/entities/wallet_entity.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final WalletEntity wallet;
  const WalletLoaded(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

// Deposit session states
class DepositSessionLoading extends WalletState {}

class DepositSessionReady extends WalletState {
  final String sessionUrl;
  final String sessionId;
  final double amount;
  const DepositSessionReady({
    required this.sessionUrl,
    required this.sessionId,
    required this.amount,
  });

  @override
  List<Object?> get props => [sessionUrl, sessionId, amount];
}

class DepositSessionError extends WalletState {
  final String message;
  const DepositSessionError(this.message);

  @override
  List<Object?> get props => [message];
}

class DepositSuccess extends WalletState {
  final double newBalance;
  final double depositedAmount;
  const DepositSuccess({required this.newBalance, required this.depositedAmount});

  @override
  List<Object?> get props => [newBalance, depositedAmount];
}

class DepositPending extends WalletState {
  const DepositPending();
}

class DepositFailed extends WalletState {
  final String message;
  const DepositFailed(this.message);

  @override
  List<Object?> get props => [message];
}

// Withdrawal states
class WithdrawLoading extends WalletState {}

class WithdrawSuccess extends WalletState {}

class WithdrawError extends WalletState {
  final String message;
  const WithdrawError(this.message);

  @override
  List<Object?> get props => [message];
}
