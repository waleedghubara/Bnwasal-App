import 'package:equatable/equatable.dart';
import '../../data/models/support_message_model.dart';

abstract class SupportState extends Equatable {
  const SupportState();

  @override
  List<Object?> get props => [];
}

class SupportInitial extends SupportState {}

// Contact Form states
class ContactSending extends SupportState {}
class ContactSuccess extends SupportState {
  final String message;
  const ContactSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
class ContactError extends SupportState {
  final String message;
  const ContactError(this.message);
  @override
  List<Object?> get props => [message];
}

// Support Chat states
class SupportChatLoading extends SupportState {}
class SupportChatLoaded extends SupportState {
  final List<SupportMessageModel> messages;
  final bool isSupportOnline;
  final String lastSeenText;
  final bool isSupportTyping;
  final String? typingAdminName;
  final String? typingAdminAvatar;
  final String? activeAdminName;
  final String? activeAdminAvatar;

  const SupportChatLoaded({
    required this.messages,
    required this.isSupportOnline,
    required this.lastSeenText,
    required this.isSupportTyping,
    this.typingAdminName,
    this.typingAdminAvatar,
    this.activeAdminName,
    this.activeAdminAvatar,
  });

  @override
  List<Object?> get props => [
        messages,
        isSupportOnline,
        lastSeenText,
        isSupportTyping,
        typingAdminName,
        typingAdminAvatar,
        activeAdminName,
        activeAdminAvatar,
      ];
}

class SupportChatError extends SupportState {
  final String message;
  const SupportChatError(this.message);
  @override
  List<Object?> get props => [message];
}
