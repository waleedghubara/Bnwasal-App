import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../data/models/notification_model.dart';

abstract class NotificationRepository {
  Future<Either<Failure, List<NotificationModel>>> getNotifications();
  Future<Either<Failure, void>> markRead(String id);
  Future<Either<Failure, void>> markAllRead();
  Future<Either<Failure, void>> deleteNotification(String id);
  Future<Either<Failure, void>> clearAllNotifications();
}
