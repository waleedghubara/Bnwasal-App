import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_wallet_usecase.dart';
import '../../domain/usecases/deposit_money_usecase.dart';
import '../../domain/usecases/withdraw_money_usecase.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final GetWalletUseCase getWalletUseCase;
  final CreateDepositSessionUseCase createDepositSessionUseCase;
  final CheckDepositSessionUseCase checkDepositSessionUseCase;
  final WithdrawMoneyUseCase withdrawMoneyUseCase;

  WalletCubit({
    required this.getWalletUseCase,
    required this.createDepositSessionUseCase,
    required this.checkDepositSessionUseCase,
    required this.withdrawMoneyUseCase,
  }) : super(WalletInitial());

  /// Load wallet balance and recent transactions
  Future<void> loadWallet() async {
    emit(WalletLoading());
    final result = await getWalletUseCase.call();
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) => emit(WalletLoaded(wallet)),
    );
  }

  /// Poll wallet silently in the background
  Future<void> pollWallet() async {
    final result = await getWalletUseCase.call();
    result.fold(
      (failure) => null,
      (wallet) => emit(WalletLoaded(wallet)),
    );
  }

  /// Step 1: Create Kashier payment session and return the sessionUrl
  Future<void> createDepositSession(double amount) async {
    emit(DepositSessionLoading());
    final result = await createDepositSessionUseCase.call(amount);
    result.fold(
      (failure) => emit(DepositSessionError(failure.message)),
      (data) {
        final sessionUrl = data['sessionUrl'] as String? ?? '';
        final sessionId = data['sessionId'] as String? ?? '';
        if (sessionUrl.isEmpty) {
          emit(const DepositSessionError('لم يتم الحصول على رابط الدفع'));
          return;
        }
        emit(DepositSessionReady(
          sessionUrl: sessionUrl,
          sessionId: sessionId,
          amount: amount,
        ));
      },
    );
  }

  /// Step 2: After WebView closes, check if payment succeeded
  Future<void> checkDepositSession(String sessionId) async {
    final result = await checkDepositSessionUseCase.call(sessionId);
    result.fold(
      (failure) => emit(DepositFailed(failure.message)),
      (data) {
        final paymentStatus = data['paymentStatus'] as String? ?? '';
        final newBalance = (data['newBalance'] as num?)?.toDouble() ?? 0.0;
        final depositedAmount = (data['depositedAmount'] as num?)?.toDouble() ?? 0.0;

        if (paymentStatus == 'success') {
          emit(DepositSuccess(
            newBalance: newBalance,
            depositedAmount: depositedAmount,
          ));
        } else if (paymentStatus == 'pending') {
          emit(const DepositPending());
        } else {
          emit(const DepositFailed('لم يتم إتمام عملية الدفع'));
        }
      },
    );
  }

  /// Reload wallet after a successful deposit
  Future<void> refreshAfterDeposit() async {
    await loadWallet();
  }

  /// Withdraw money
  Future<void> withdrawMoney({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    emit(WithdrawLoading());
    final result = await withdrawMoneyUseCase.call(
      amount: amount,
      paymentMethod: paymentMethod,
      name: name,
      phone: phone,
      walletProvider: walletProvider,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
    );
    result.fold(
      (failure) => emit(WithdrawError(failure.message)),
      (_) {
        emit(WithdrawSuccess());
        loadWallet(); // Reload wallet so pending withdrawal details are fetched
      },
    );
  }
}
