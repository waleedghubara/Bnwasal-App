import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../data/models/notification_model.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  final NotificationRepository repository;
  GetNotificationsUseCase(this.repository);

  Future<Either<Failure, List<NotificationModel>>> call() async {
    return await repository.getNotifications();
  }
}

class MarkNotificationReadUseCase {
  final NotificationRepository repository;
  MarkNotificationReadUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.markRead(id);
  }
}

class MarkAllNotificationsReadUseCase {
  final NotificationRepository repository;
  MarkAllNotificationsReadUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.markAllRead();
  }
}

class DeleteNotificationUseCase {
  final NotificationRepository repository;
  DeleteNotificationUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteNotification(id);
  }
}

class ClearAllNotificationsUseCase {
  final NotificationRepository repository;
  ClearAllNotificationsUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.clearAllNotifications();
  }
}
