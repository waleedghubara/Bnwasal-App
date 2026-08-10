import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/user_messages_api.dart';
import 'user_messages_state.dart';

class UserMessagesCubit extends Cubit<UserMessagesState> {
  final UserMessagesApi _api;

  UserMessagesCubit(this._api) : super(const UserMessagesState());

  Future<void> loadMessages() async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      final data = await _api.getUserMessages();
      final messages = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      emit(state.copyWith(
        isLoading: false,
        messages: messages,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'فشل تحميل رسائل المستخدمين'));
    }
  }

  Future<void> deleteMessage(int id) async {
    emit(state.copyWith(isDeleting: true, error: null, successMessage: null));
    try {
      await _api.deleteUserMessage(id);
      
      // Update local list
      final updatedList = List<Map<String, dynamic>>.from(state.messages)
        ..removeWhere((msg) => msg['id'] == id);

      final isSelectedDeleted = state.selectedMessage != null && state.selectedMessage!['id'] == id;

      emit(state.copyWith(
        isDeleting: false,
        messages: updatedList,
        clearSelectedMessage: isSelectedDeleted,
        successMessage: '✅ تم حذف الرسالة بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isDeleting: false, error: 'فشل حذف الرسالة'));
    }
  }

  void selectMessage(Map<String, dynamic> msg) {
    emit(state.copyWith(selectedMessage: msg));
  }

  void clearSelectedMessage() {
    emit(state.copyWith(clearSelectedMessage: true));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setSourceFilter(String source) {
    emit(state.copyWith(sourceFilter: source));
  }

  void clearMessages() {
    emit(state.copyWith(error: null, successMessage: null));
  }
}
