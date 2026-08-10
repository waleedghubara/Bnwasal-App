import 'package:equatable/equatable.dart';

class ComplaintsState extends Equatable {
  final bool isLoading;
  final bool isLoadingChat;
  final String? error;
  final List<dynamic> threads;
  final List<dynamic> activeMessages;
  final int? selectedUserId;
  final bool isClientOnline;
  final bool isClientTyping;
  final Map<String, Map<String, dynamic>> autoLookupResults;

  const ComplaintsState({
    this.isLoading = false,
    this.isLoadingChat = false,
    this.error,
    this.threads = const [],
    this.activeMessages = const [],
    this.selectedUserId,
    this.isClientOnline = false,
    this.isClientTyping = false,
    this.autoLookupResults = const {},
  });

  ComplaintsState copyWith({
    bool? isLoading,
    bool? isLoadingChat,
    String? error,
    List<dynamic>? threads,
    List<dynamic>? activeMessages,
    int? selectedUserId,
    bool? isClientOnline,
    bool? isClientTyping,
    bool clearSelectedUser = false,
    Map<String, Map<String, dynamic>>? autoLookupResults,
  }) {
    return ComplaintsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingChat: isLoadingChat ?? this.isLoadingChat,
      error: error,
      threads: threads ?? this.threads,
      activeMessages: activeMessages ?? this.activeMessages,
      selectedUserId: clearSelectedUser ? null : (selectedUserId ?? this.selectedUserId),
      isClientOnline: isClientOnline ?? this.isClientOnline,
      isClientTyping: isClientTyping ?? this.isClientTyping,
      autoLookupResults: autoLookupResults ?? this.autoLookupResults,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isLoadingChat,
        error,
        threads,
        activeMessages,
        selectedUserId,
        isClientOnline,
        isClientTyping,
        autoLookupResults,
      ];
}
