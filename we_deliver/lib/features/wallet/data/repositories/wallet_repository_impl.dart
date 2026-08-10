// ignore_for_file: void_checks

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

/// Extracts a human-readable Arabic message from any exception.
/// For DioException, reads the backend JSON `message` field.
/// Falls back to a generic Arabic message if parsing fails.
String _extractErrorMessage(dynamic e, {String fallback = 'حدث خطأ غير متوقع'}) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    }
    // Connection/timeout errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'انتهت مهلة الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
    }
  }
  return fallback;
}

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, WalletEntity>> getWalletData() async {
    try {
      final remoteWallet = await remoteDataSource.getWalletData();
      return Right(remoteWallet);
    } catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e, fallback: 'فشل تحميل بيانات المحفظة'),
      ));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createDepositSession(
    double amount,
  ) async {
    try {
      final result = await remoteDataSource.createDepositSession(amount);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e, fallback: 'فشل إنشاء جلسة الدفع'),
      ));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> checkDepositSession(
    String sessionId,
  ) async {
    try {
      final result = await remoteDataSource.checkDepositSession(sessionId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e, fallback: 'فشل التحقق من حالة الدفع'),
      ));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDataSource.getTransactions(
        page: page,
        limit: limit,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e, fallback: 'فشل تحميل المعاملات'),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> withdrawMoney({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    try {
      await remoteDataSource.withdrawMoney(
        amount: amount,
        paymentMethod: paymentMethod,
        name: name,
        phone: phone,
        walletProvider: walletProvider,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e, fallback: 'فشل تقديم طلب السحب'),
      ));
    }
  }
}
