import 'package:dio/dio.dart';
import 'package:we_deliver/core/api/end_point.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';

abstract class WalletRemoteDataSource {
  Future<WalletModel> getWalletData();
  Future<Map<String, dynamic>> createDepositSession(double amount);
  Future<Map<String, dynamic>> checkDepositSession(String sessionId);
  Future<List<TransactionModel>> getTransactions({int page = 1, int limit = 20});
  Future<void> withdrawMoney({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  });
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final Dio dio;

  WalletRemoteDataSourceImpl({required this.dio});

  @override
  Future<WalletModel> getWalletData() async {
    final response = await dio.get('${EndPoint.baseUrl}${EndPoint.getWalletData}');
    final data = response.data['data'];
    return WalletModel.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> createDepositSession(double amount) async {
    final response = await dio.post(
      '${EndPoint.baseUrl}${EndPoint.createDepositSession}',
      data: {'amount': amount.toStringAsFixed(2)},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> checkDepositSession(String sessionId) async {
    final response = await dio.post(
      '${EndPoint.baseUrl}${EndPoint.checkDepositSession}',
      data: {'sessionId': sessionId},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await dio.get(
      '${EndPoint.baseUrl}${EndPoint.getTransactions}',
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = response.data['data']['transactions'] as List;
    return list.map((e) => TransactionModel.fromJson(e)).toList();
  }

  @override
  Future<void> withdrawMoney({
    required double amount,
    required String paymentMethod,
    required String name,
    String? phone,
    String? walletProvider,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    await dio.post(
      '${EndPoint.baseUrl}${EndPoint.withdraw}',
      data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'name': name,
        '?phone': phone,
        '?walletProvider': walletProvider,
        '?bankName': bankName,
        '?bankAccountNumber': bankAccountNumber,
      },
    );
  }
}
