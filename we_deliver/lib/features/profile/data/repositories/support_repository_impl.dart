import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_remote_data_source.dart';
import '../models/support_message_model.dart';

class SupportRepositoryImpl implements SupportRepository {
  final SupportRemoteDataSource remoteDataSource;

  SupportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      await remoteDataSource.submitContactMessage(
        name: name,
        email: email,
        subject: subject,
        message: message,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SupportMessageModel>>> getSupportMessages({int? afterId}) async {
    try {
      final messages = await remoteDataSource.getSupportMessages(afterId: afterId);
      return Right(messages);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SupportMessageModel>> sendSupportMessage({
    required String text,
    String? imagePath,
  }) async {
    try {
      final message = await remoteDataSource.sendSupportMessage(
        text: text,
        imagePath: imagePath,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
