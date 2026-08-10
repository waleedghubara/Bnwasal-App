import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/send_notification_api.dart';
import 'send_notification_state.dart';

class SendNotificationCubit extends Cubit<SendNotificationState> {
  final SendNotificationApi _api;
  SendNotificationCubit(this._api) : super(const SendNotificationState());

  void setTargetType(String type) {
    emit(state.copyWith(targetType: type, targetUsers: [], selectedUserIds: {}));
    if (type != 'all') {
      fetchTargetUsers(type);
    }
  }

  Future<void> fetchTargetUsers(String targetType) async {
    emit(state.copyWith(isLoadingUsers: true));
    try {
      final users = await _api.getTargetUsers(targetType);
      emit(state.copyWith(isLoadingUsers: false, targetUsers: users));
    } catch (e) {
      emit(state.copyWith(isLoadingUsers: false));
    }
  }

  void toggleUserSelection(String userId) {
    final selected = Set<String>.from(state.selectedUserIds);
    if (selected.contains(userId)) {
      selected.remove(userId);
    } else {
      selected.add(userId);
    }
    emit(state.copyWith(selectedUserIds: selected));
  }

  void selectAllUsers() {
    final allIds = state.targetUsers.map((u) => u['id'].toString()).toSet();
    emit(state.copyWith(selectedUserIds: allIds));
  }

  void deselectAllUsers() {
    emit(state.copyWith(selectedUserIds: {}));
  }

  Future<void> send({
    required String title,
    required String body,
  }) async {
    emit(state.copyWith(isLoading: true, error: null, isSuccess: false));
    try {
      final response = await _api.sendBulk(
        targetType: state.targetType,
        specificUserIds: state.selectedUserIds.isNotEmpty ? state.selectedUserIds.toList() : null,
        title: title,
        body: body,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        sentCount: data['sent'] as int? ?? 0,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().contains('غير مصرح')
            ? 'غير مصرح لك بإرسال الإشعارات'
            : 'فشل إرسال الإشعار',
      ));
    }
  }

  void reset() {
    emit(const SendNotificationState());
  }
}
