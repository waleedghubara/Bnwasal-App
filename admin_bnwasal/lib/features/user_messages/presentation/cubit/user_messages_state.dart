import 'package:equatable/equatable.dart';

class UserMessagesState extends Equatable {
  final bool isLoading;
  final bool isDeleting;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic>? selectedMessage;
  final String searchQuery;
  final String sourceFilter;
  final String? error;
  final String? successMessage;

  const UserMessagesState({
    this.isLoading = false,
    this.isDeleting = false,
    this.messages = const [],
    this.selectedMessage,
    this.searchQuery = '',
    this.sourceFilter = 'all',
    this.error,
    this.successMessage,
  });

  UserMessagesState copyWith({
    bool? isLoading,
    bool? isDeleting,
    List<Map<String, dynamic>>? messages,
    Map<String, dynamic>? selectedMessage,
    String? searchQuery,
    String? sourceFilter,
    String? error,
    String? successMessage,
    bool clearSelectedMessage = false,
  }) {
    return UserMessagesState(
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      messages: messages ?? this.messages,
      selectedMessage: clearSelectedMessage ? null : (selectedMessage ?? this.selectedMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isDeleting,
        messages,
        selectedMessage,
        searchQuery,
        sourceFilter,
        error,
        successMessage,
      ];
}
