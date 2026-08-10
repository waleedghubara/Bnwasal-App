import 'package:equatable/equatable.dart';
import '../../domain/entities/message_entity.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<MessageEntity> messages;
  final bool isOtherUserOnline;

  const ChatLoaded(this.messages, {this.isOtherUserOnline = false});

  @override
  List<Object?> get props => [messages, isOtherUserOnline];
}

class ChatSending extends ChatState {
  final List<MessageEntity> messages;
  final bool isOtherUserOnline;

  const ChatSending(this.messages, {this.isOtherUserOnline = false});

  @override
  List<Object?> get props => [messages, isOtherUserOnline];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
