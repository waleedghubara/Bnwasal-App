import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class GetWalletUseCase {
  final WalletRepository repository;

  GetWalletUseCase(this.repository);

  Future<Either<Failure, WalletEntity>> call() async {
    return await repository.getWalletData();
  }
}
