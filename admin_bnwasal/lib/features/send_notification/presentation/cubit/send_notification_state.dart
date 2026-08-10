import 'package:equatable/equatable.dart';

class SendNotificationState extends Equatable {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final String targetType;
  final int sentCount;
  final List<Map<String, dynamic>> targetUsers;
  final Set<String> selectedUserIds;
  final bool isLoadingUsers;

  const SendNotificationState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.targetType = 'all',
    this.sentCount = 0,
    this.targetUsers = const [],
    this.selectedUserIds = const {},
    this.isLoadingUsers = false,
  });

  SendNotificationState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    String? targetType,
    int? sentCount,
    List<Map<String, dynamic>>? targetUsers,
    Set<String>? selectedUserIds,
    bool? isLoadingUsers,
  }) {
    return SendNotificationState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      targetType: targetType ?? this.targetType,
      sentCount: sentCount ?? this.sentCount,
      targetUsers: targetUsers ?? this.targetUsers,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
      isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSuccess, error, targetType, sentCount, targetUsers, selectedUserIds, isLoadingUsers];
}
