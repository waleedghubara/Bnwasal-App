// ignore_for_file: avoid_print, library_prefixes
import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../data/models/support_message_model.dart';
import '../../domain/usecases/support_usecases.dart';
import 'support_state.dart';

class SupportCubit extends Cubit<SupportState> {
  final SubmitContactMessageUseCase submitContactUseCase;
  final GetSupportMessagesUseCase getMessagesUseCase;
  final SendSupportMessageUseCase sendMessageUseCase;

  IO.Socket? _socket;
  List<SupportMessageModel> _messages = [];
  String? _userId;
  bool _isSupportOnline = false;
  String _lastSeenText = "غير متصل";
  String _currentPresenceStatus = "offline";
  bool _isSupportTyping = false;
  String? _typingAdminName;
  String? _typingAdminAvatar;
  String? _activeAdminName;
  String? _activeAdminAvatar;

  SupportCubit({
    required this.submitContactUseCase,
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
  }) : super(SupportInitial());

  // 1. Submit Contact Form
  Future<void> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    emit(ContactSending());
    final result = await submitContactUseCase(
      name: name,
      email: email,
      subject: subject,
      message: message,
    );

    result.fold(
      (failure) => emit(ContactError(failure.message)),
      (_) => emit(
        const ContactSuccess(
          'تم إرسال رسالتك بنجاح وسيتواصل معك الدعم قريباً.',
        ),
      ),
    );
  }

  // 2. Initialize Support Chat
  Future<void> initSupportChat() async {
    _isSupportOnline = false;
    _lastSeenText = "خارج الشكاوي";
    _currentPresenceStatus = "offline";
    _isSupportTyping = false;
    _typingAdminName = null;
    _typingAdminAvatar = null;
    _activeAdminName = null;
    _activeAdminAvatar = null;
    
    try {
      _userId = await SecureCacheHelper().getData(key: ApiKey.id);
      
      if (_userId != null) {
        final cacheKey = '${_userId}_support_messages_cache';
        final cachedData = await SecureCacheHelper().getData(key: cacheKey);
        if (cachedData != null) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedData);
            _messages = decoded.map((e) => SupportMessageModel.fromJson(e)).toList();
          } catch (e) {
            print('❌ Error decoding cached support messages: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading cached support messages: $e');
    }

    if (_messages.isEmpty) {
      emit(SupportChatLoading());
    } else {
      emit(_buildLoadedState());
      _connectSocket();
    }

    try {
      int? afterId;
      if (_messages.isNotEmpty) {
        try {
          afterId = _messages.map((m) => int.parse(m.id)).reduce((a, b) => a > b ? a : b);
        } catch (e) {
          afterId = int.tryParse(_messages.last.id);
        }
      }

      final result = await getMessagesUseCase(afterId: afterId);

      result.fold(
        (failure) {
          if (_messages.isEmpty) {
            emit(SupportChatError(failure.message));
          }
        },
        (newMessages) async {
          if (newMessages.isNotEmpty) {
            final existingIds = _messages.map((m) => m.id).toSet();
            for (final msg in newMessages) {
              if (!existingIds.contains(msg.id)) {
                _messages.add(msg);
              }
            }

            if (_userId != null) {
              final cacheKey = '${_userId}_support_messages_cache';
              final jsonList = _messages.map((m) => m.toJson()).toList();
              await SecureCacheHelper().saveData(
                key: cacheKey,
                value: jsonEncode(jsonList),
              );
            }
          }
          emit(_buildLoadedState());
          if (_socket == null) {
            _connectSocket();
          }
        },
      );
    } catch (e) {
      if (_messages.isEmpty) {
        emit(SupportChatError(e.toString()));
      }
    }
  }

  void _updatePresenceText(String status) {
    _currentPresenceStatus = status;
    if (_isSupportTyping) return; // Keep "يكتب الآن..." if currently typing

    if (status == 'online') {
      _isSupportOnline = true;
      _lastSeenText = "متصل الآن";
    } else if (status == 'left') {
      _isSupportOnline = false;
      _lastSeenText = "خارج المحادثة";
    } else {
      _isSupportOnline = false;
      _lastSeenText = "خارج الشكاوي";
    }
  }

  void _connectSocket() async {
    print('🔌 Support Chat Socket: attempting to connect for user $_userId');
    if (_userId == null) {
      print('⚠️ Support Chat Socket: cannot connect because _userId is null');
      return;
    }

    try {
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

      _socket!.onConnect((_) {
        print('🔌 Support Chat Socket connected successfully: ${_socket!.id}');
        _socket!.emit('joinRoom', 'support_$_userId');
        print('📤 Support Chat Socket emitted auth & joinRoom for support_$_userId');
      });

      _socket!.on('online_users', (data) {
        print('🟢 Support Chat online_users: $data');
        if (data is List) {
          final otherUsers = data
              .where((uid) => uid.toString() != _userId)
              .toList();
          if (otherUsers.isNotEmpty) {
            _updatePresenceText('online');
          }
          emit(_buildLoadedState());
        }
      });

      _socket!.on('support_presence_status', (data) {
        print('🛡️ Support presence status: $data');
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final presenceStatus = mapData['status']?.toString();
          if (presenceStatus != null) {
            _updatePresenceText(presenceStatus);
            if (presenceStatus == 'online') {
              _activeAdminName = mapData['name']?.toString();
              _activeAdminAvatar = mapData['avatar']?.toString();
            } else {
              _activeAdminName = null;
              _activeAdminAvatar = null;
            }
            emit(_buildLoadedState());
          }
        }
      });

      _socket!.on('user_presence', (data) {
        print('👤 Support Chat user_presence: $data');
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final presenceUserId = mapData['userId']?.toString();
          final presenceStatus = mapData['status']?.toString();
          final role = mapData['role']?.toString();
          if (presenceUserId != null && presenceUserId != _userId) {
            if (role == 'admin' || role == 'employee') {
              _updatePresenceText(presenceStatus ?? 'offline');
              if (presenceStatus == 'online') {
                _activeAdminName = mapData['name']?.toString();
                _activeAdminAvatar = mapData['avatar']?.toString();
              } else {
                _activeAdminName = null;
                _activeAdminAvatar = null;
              }
            }
            emit(_buildLoadedState());
          }
        }
      });

      _socket!.on('typing', (data) {
        print('⌨️ Support Chat typing: $data');
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final roomName = mapData['roomName']?.toString();
          if (roomName == 'support_$_userId') {
            final isTyping = mapData['isTyping'] as bool? ?? false;
            _isSupportTyping = isTyping;
            if (isTyping) {
              _typingAdminName = mapData['senderName'] ?? 'الدعم الفني بنوصل';
              _typingAdminAvatar = mapData['senderAvatar'];
              _lastSeenText = "يكتب الآن...";
            } else {
              _typingAdminName = null;
              _typingAdminAvatar = null;
              _updatePresenceText(_currentPresenceStatus);
            }
            emit(_buildLoadedState());
          }
        }
      });

      _socket!.on('supportMessage', (data) async {
        print('📩 Support Chat received message: $data');
        if (data != null && data is Map) {
          try {
            final mapData = Map<String, dynamic>.from(data);
            final senderRole = mapData['senderRole']?.toString();
            final isUserMessage = senderRole != 'admin' && senderRole != 'employee';

            final message = SupportMessageModel.fromJson(mapData).copyWith(
              isUser: isUserMessage,
            );

            if (!_messages.any((msg) => msg.id == message.id)) {
              _messages.add(message);
              emit(_buildLoadedState());
              
              // Save to cache
              if (_userId != null) {
                final cacheKey = '${_userId}_support_messages_cache';
                final jsonList = _messages.map((m) => m.toJson()).toList();
                await SecureCacheHelper().saveData(
                  key: cacheKey,
                  value: jsonEncode(jsonList),
                );
              }
            }
          } catch (e) {
            print('❌ Error parsing supportMessage: $e');
          }
        }
      });

      _socket!.onDisconnect((_) {
        print('🔌 Support Chat Socket disconnected');
      });

      _socket!.onConnectError((data) {
        print('❌ Support Chat Socket error: $data');
      });

      _socket!.connect();
    } catch (e) {
      print('❌ Support Chat Socket setup error: $e');
    }
  }

  // Send Typing Indicator
  Future<void> sendTypingState(bool isTyping) async {
    if (_socket == null || _userId == null) return;
    try {
      final name =
          await SecureCacheHelper().getData(key: ApiKey.name) ?? 'مستخدم بنوصل';
      final avatar = await SecureCacheHelper().getData(
        key: ApiKey.profileImage,
      );

      _socket!.emit('typing', {
        'roomName': 'support_$_userId',
        'isTyping': isTyping,
        'senderName': name,
        'senderAvatar': avatar,
      });
    } catch (e) {
      print('Error sending typing state: $e');
    }
  }

  // 3. Send Message
  Future<void> sendSupportMessage({
    required String text,
    String? imagePath,
  }) async {
    if (_userId == null) return;

    // Local temporary message for instant response UI
    final tempMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = SupportMessageModel(
      id: tempMsgId,
      text: text,
      timestamp: DateTime.now(),
      isUser: true,
      status: SupportMessageStatus.sent,
      imagePath: imagePath,
      senderName: 'أنا',
      senderRole: 'user',
    );

    _messages.add(tempMessage);
    emit(_buildLoadedState());

    final result = await sendMessageUseCase(text: text, imagePath: imagePath);

    result.fold(
      (failure) {
        _messages.removeWhere((m) => m.id == tempMsgId);
        emit(SupportChatError(failure.message));
        emit(_buildLoadedState());
      },
      (savedMessage) async {
        // Replace temp message or remove it if already added by socket
        _messages.removeWhere((m) => m.id == tempMsgId);
        if (!_messages.any((m) => m.id == savedMessage.id)) {
          _messages.add(savedMessage.copyWith(isUser: true));
        }
        emit(_buildLoadedState());

        // Cache updated message list
        if (_userId != null) {
          final cacheKey = '${_userId}_support_messages_cache';
          final jsonList = _messages.map((m) => m.toJson()).toList();
          await SecureCacheHelper().saveData(
            key: cacheKey,
            value: jsonEncode(jsonList),
          );
        }
      },
    );
  }

  SupportChatLoaded _buildLoadedState() {
    return SupportChatLoaded(
      messages: List.from(_messages),
      isSupportOnline: _isSupportOnline,
      lastSeenText: _lastSeenText,
      isSupportTyping: _isSupportTyping,
      typingAdminName: _typingAdminName,
      typingAdminAvatar: _typingAdminAvatar,
      activeAdminName: _activeAdminName,
      activeAdminAvatar: _activeAdminAvatar,
    );
  }

  @override
  void emit(SupportState state) {
    if (isClosed) return;
    super.emit(state);
  }

  @override
  Future<void> close() {
    if (_socket != null && _userId != null) {
      _socket!.emit('leaveRoom', 'support_$_userId');
      _socket!.disconnect();
      _socket!.destroy();
    }
    return super.close();
  }
}
