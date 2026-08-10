import 'package:equatable/equatable.dart';

class NotificationsState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final String? error;

  const NotificationsState({
    this.isLoading = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.error,
  });

  NotificationsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    String? error,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, notifications, unreadCount, error];
}
