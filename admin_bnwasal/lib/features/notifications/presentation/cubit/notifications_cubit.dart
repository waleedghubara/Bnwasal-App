import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/text_sanitizer.dart';
import '../../data/notifications_api.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsApi _api;
  NotificationsCubit(this._api) : super(const NotificationsState());

  Map<String, dynamic> _sanitize(Map<String, dynamic> n) {
    return {
      ...n,
      'title': sanitizeText(n['title'] as String?),
      'body': sanitizeText(n['body'] as String?),
    };
  }

  Future<void> loadNotifications() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final response = await _api.getNotifications();
      final data = response['data'] as List<dynamic>? ?? [];
      final notifications = data
          .map((e) => _sanitize(e as Map<String, dynamic>))
          .toList();
      final unread = notifications
          .where((n) => n['isRead'] == 0 || n['isRead'] == false)
          .length;
      emit(
        state.copyWith(
          isLoading: false,
          notifications: notifications,
          unreadCount: unread,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'فشل تحميل الإشعارات'));
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.markAsRead(id);
      final updated = state.notifications.map((n) {
        if (n['id'].toString() == id) {
          return {...n, 'isRead': 1};
        }
        return n;
      }).toList();
      emit(
        state.copyWith(
          notifications: updated,
          unreadCount: updated
              .where((n) => n['isRead'] == 0 || n['isRead'] == false)
              .length,
        ),
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.markAllAsRead();
      final updated = state.notifications
          .map((n) => {...n, 'isRead': 1})
          .toList();
      emit(state.copyWith(notifications: updated, unreadCount: 0));
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.deleteNotification(id);
      final updated = state.notifications
          .where((n) => n['id'].toString() != id)
          .toList();
      emit(
        state.copyWith(
          notifications: updated,
          unreadCount: updated
              .where((n) => n['isRead'] == 0 || n['isRead'] == false)
              .length,
        ),
      );
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await _api.clearAll();
      emit(state.copyWith(notifications: [], unreadCount: 0));
    } catch (_) {}
  }

  void addNotification(Map<String, dynamic> notification) {
    final sanitized = _sanitize(notification);
    final updated = [sanitized, ...state.notifications];
    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: updated
            .where((n) => n['isRead'] == 0 || n['isRead'] == false)
            .length,
      ),
    );
  }
}
