import 'package:dartz/dartz.dart';
import 'package:we_deliver/core/errors/failure.dart';
import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository repository;
  const GetProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() => repository.getProfile();
}
