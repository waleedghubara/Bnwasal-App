// ignore_for_file: library_prefixes, avoid_print

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'chat_state.dart';
import '../../data/models/message_model.dart';

class ChatCubit extends Cubit<ChatState> {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;

  IO.Socket? _socket;
  List<MessageEntity> _messages = [];
  String? _currentShipmentId;
  bool _isOtherUserOnline = false;

  ChatCubit({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
  }) : super(ChatInitial());

  Future<void> initChat(String shipmentId) async {
    _currentShipmentId = shipmentId;
    _isOtherUserOnline = false;
    emit(ChatLoading());

    // 1. Fetch historical messages
    try {
      final messages = await getMessagesUseCase(shipmentId);
      _messages = List.from(messages);
      emit(ChatLoaded(_messages, isOtherUserOnline: _isOtherUserOnline));
    } catch (e) {
      emit(ChatError(e.toString()));
      return;
    }

    // 2. Setup Socket.io connection
    _connectSocket(shipmentId);
  }

  void _connectSocket(String shipmentId) async {
    try {
      final userId = await SecureCacheHelper().getData(key: ApiKey.id);
      final token = await SecureCacheHelper().getData(key: ApiKey.token);

      _socket = IO.io(
        EndPoint.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setAuth({'token': token ?? ''})
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        print('🔌 Socket connected successfully: ${_socket!.id}');
        _socket!.emit('joinRoom', 'shipment_$shipmentId');
      });

      _socket!.on('online_users', (data) {
        print('🟢 Socket received online_users: $data');
        if (data is List) {
          final otherUsers = data.where((uid) => uid.toString() != userId).toList();
          _isOtherUserOnline = otherUsers.isNotEmpty;
          if (!isClosed) {
            emit(ChatLoaded(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
          }
        }
      });

      _socket!.on('user_presence', (data) {
        print('👤 Socket received user_presence: $data');
        if (data is Map) {
          final presenceUserId = data['userId']?.toString();
          final presenceStatus = data['status']?.toString();
          if (presenceUserId != null && presenceUserId != userId) {
            _isOtherUserOnline = (presenceStatus == 'online');
            if (!isClosed) {
              emit(ChatLoaded(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
            }
          }
        }
      });

      _socket!.on('new_message', (data) {
        print('📩 Socket received message event: $data');
        final message = MessageModel.fromJson(data as Map<String, dynamic>);

        if (!_messages.any((msg) => msg.id == message.id)) {
          _messages.add(message);
          if (!isClosed) {
            emit(ChatLoaded(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
          }
        }
      });

      _socket!.on('chat_deleted', (data) {
        print('🗑️ Socket received chat_deleted event: $data');
        if (!isClosed) {
          emit(const ChatError('CHAT_DELETED'));
        }
      });

      _socket!.onDisconnect((_) {
        print('🔌 Socket disconnected');
      });

      _socket!.onConnectError((data) {
        print('❌ Socket connect error: $data');
      });
    } catch (e) {
      print('❌ Socket setup error: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (_currentShipmentId == null) return;

    emit(ChatSending(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
    try {
      final message = await sendMessageUseCase(_currentShipmentId!, text);

      if (!_messages.any((msg) => msg.id == message.id)) {
        _messages.add(message);
      }
      emit(ChatLoaded(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
    } catch (e) {
      emit(ChatError(e.toString()));
      emit(ChatLoaded(List.from(_messages), isOtherUserOnline: _isOtherUserOnline));
    }
  }

  @override
  void emit(ChatState state) {
    if (isClosed) return;
    super.emit(state);
  }

  @override
  Future<void> close() {
    if (_socket != null && _currentShipmentId != null) {
      _socket!.emit('leaveRoom', 'shipment_$_currentShipmentId');
      _socket!.disconnect();
      _socket!.destroy();
    }
    return super.close();
  }
}
