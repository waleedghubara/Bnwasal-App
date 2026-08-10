import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../data/complaints_api.dart';
import 'complaints_state.dart';

class ComplaintsCubit extends Cubit<ComplaintsState> {
  final ComplaintsApi _api;
  IO.Socket? _socket;
  String? _adminId;
  final Map<int, List<dynamic>> _chatCache = {};
  bool _isInComplaintsPage = false;

  ComplaintsCubit(this._api) : super(const ComplaintsState());

  void enterComplaintsPage() {
    _isInComplaintsPage = true;
    _connectSocket();
    if (_socket != null && _socket!.connected) {
      _socket!.emit('joinRoom', 'complaints_agents');
      // ignore: avoid_print
      print('📤 Admin Chat Socket: emitted joinRoom for complaints_agents');
    }
  }

  void leaveComplaintsPage() {
    _isInComplaintsPage = false;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leaveRoom', 'complaints_agents');
      // ignore: avoid_print
      print('📤 Admin Chat Socket: emitted leaveRoom for complaints_agents');
    }
  }

  // Set the current admin's ID (retrieved from AuthCubit)
  void setAdminId(String adminId) {
    _adminId = adminId;
  }

  // Load all complaint threads
  Future<void> loadComplaints() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final response = await _api.getComplaints();
      final threads = (response['data'] as List<dynamic>)
          .map((t) => Map<String, dynamic>.from(t as Map))
          .toList();
      emit(state.copyWith(isLoading: false, threads: threads));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // Open chat room for a client
  Future<void> openChat(Map<String, dynamic> thread, {String? adminId}) async {
    if (adminId != null) {
      _adminId = adminId;
    }
    final userId = int.parse(thread['userId'].toString());

    // Leave the previous chat room if any
    if (state.selectedUserId != null && state.selectedUserId != userId) {
      _socket?.emit('leaveRoom', 'support_${state.selectedUserId}');
    }

    // Check if the chat is already in cache
    final cached = _chatCache[userId];
    if (cached != null) {
      emit(state.copyWith(
        isLoadingChat: false,
        selectedUserId: userId,
        activeMessages: cached,
        isClientOnline: false,
        isClientTyping: false,
      ));
    } else {
      emit(state.copyWith(
        isLoadingChat: true,
        selectedUserId: userId,
        activeMessages: [],
        isClientOnline: false,
        isClientTyping: false,
      ));
    }
    
    // Connect socket if not already connected
    _connectSocket();

    try {
      // Join Room via Socket.IO
      if (_socket != null && _socket!.connected) {
        _socket!.emit('joinRoom', 'support_$userId');
        // ignore: avoid_print
        print('📤 Admin Chat Socket: emitted joinRoom support_$userId');
      }

      final response = await _api.getMessages(userId);
      final messages = response['data'] as List<dynamic>;

      // Map incoming messages to indicate if they were sent by the admin (current user)
      final mappedMessages = messages.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        final senderRole = map['senderRole']?.toString();
        return {
          ...map,
          'isUser': senderRole == 'admin' || senderRole == 'employee', // in admin panel, admin sent messages are "isUser = true"
        };
      }).toList();

      // Save to cache
      _chatCache[userId] = mappedMessages;

      emit(state.copyWith(
        isLoadingChat: false,
        activeMessages: mappedMessages,
      ));

      // Auto-lookup patterns in loaded messages
      autoLookupAllActiveMessages();

      // Reset unread count for this thread in local state list
      final updatedThreads = state.threads.map((t) {
        final map = Map<String, dynamic>.from(t as Map);
        if (map['userId'] == userId) {
          return {...map, 'unreadCount': 0};
        }
        return map;
      }).toList();
      emit(state.copyWith(threads: updatedThreads));

    } catch (e) {
      emit(state.copyWith(isLoadingChat: false, error: e.toString()));
    }
  }

  // Leave active chat room
  void leaveChat() {
    if (state.selectedUserId != null && _socket != null && _socket!.connected) {
      _socket!.emit('leaveRoom', 'support_${state.selectedUserId}');
    }
    emit(state.copyWith(
      clearSelectedUser: true,
      activeMessages: [],
      isClientOnline: false,
      isClientTyping: false,
    ));
  }

  // Send Typing Indicator
  void sendTypingState(bool isTyping, {String? senderName, String? senderAvatar}) {
    if (_socket == null || !_socket!.connected || state.selectedUserId == null) return;
    try {
      _socket!.emit('typing', {
        'roomName': 'support_${state.selectedUserId}',
        'isTyping': isTyping,
        'senderName': senderName ?? 'الدعم الفني بنوصل',
        'senderAvatar': senderAvatar ?? '/uploads/default-admin.png',
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error sending admin typing state: $e');
    }
  }

  // Auto-detect patterns in message text and fetch related data
  Future<void> autoLookupMessage(Map<String, dynamic> message) async {
    final text = (message['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return;
    final query = _extractLookupQuery(text);
    if (query == null) return;

    final msgKey = message['id']?.toString() ?? text;
    // Skip if already fetched for this message
    if (state.autoLookupResults.containsKey(msgKey)) return;

    try {
      final response = await _api.lookup(query);
      final result = response['data'] as Map<String, dynamic>?;
      if (result == null) return;
      final hasData = (result['users'] as List?)?.isNotEmpty == true ||
          (result['orders'] as List?)?.isNotEmpty == true ||
          (result['shipments'] as List?)?.isNotEmpty == true;
      if (!hasData) return;

      final updated = Map<String, Map<String, dynamic>>.from(state.autoLookupResults)
        ..[msgKey] = result;
      emit(state.copyWith(autoLookupResults: updated));
    } catch (_) {}
  }

  // Extract email, phone, order, or shipment reference from text
  String? _extractLookupQuery(String text) {
    // 1. Email
    final emailMatch = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,}\b').firstMatch(text);
    if (emailMatch != null) return emailMatch.group(0);

    // 2. Egyptian mobile: 01 followed by 9 digits
    final phoneMatch = RegExp(r'\b(01)[0-9]{9}\b').firstMatch(text);
    if (phoneMatch != null) return phoneMatch.group(0);

    // 3. Order number: ORD followed by digits
    final orderMatch = RegExp(r'\bORD[0-9]+\b').firstMatch(text);
    if (orderMatch != null) return orderMatch.group(0);

    // 4. Shipment number: H followed by digits
    final shipmentMatch = RegExp(r'\bH[0-9]+\b').firstMatch(text);
    if (shipmentMatch != null) return shipmentMatch.group(0);

    // 5. Plain numeric sequence >= 4 digits (generic order/shipment ref)
    final numericMatch = RegExp(r'\b[0-9]{4,}\b').firstMatch(text);
    if (numericMatch != null) return numericMatch.group(0);

    return null;
  }

  // Scan all active messages for lookup patterns
  Future<void> autoLookupAllActiveMessages() async {
    for (final msg in state.activeMessages) {
      final map = Map<String, dynamic>.from(msg as Map);
      // Only lookup client messages (not admin)
      if (map['isUser'] == true) continue;
      await autoLookupMessage(map);
    }
  }

  // Send a message reply to the active complaint
  Future<void> sendReply(String text, {String? imagePath}) async {
    final userId = state.selectedUserId;
    if (userId == null) return;

    // Optimistically add the message to the active messages list
    final tempMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = {
      'id': tempMsgId,
      'text': text,
      'imagePath': imagePath,
      'isUser': true,
      'status': 'sent',
      'timestamp': DateTime.now().toIso8601String(),
      'senderName': 'الدعم الفني بنوصل',
      'senderRole': 'admin',
      'senderAvatar': '/uploads/default-admin.png',
    };

    final updatedMessages = List<dynamic>.from(state.activeMessages)..add(tempMsg);
    emit(state.copyWith(activeMessages: updatedMessages));
    _chatCache[userId] = updatedMessages;

    try {
      final response = await _api.replyToComplaint(userId, text, imagePath: imagePath);
      final savedMessage = response['data'] as Map<String, dynamic>;

      // Map isUser to true for the UI representation
      final mappedMessage = {
        ...savedMessage,
        'isUser': true,
      };

      // Replace optimistic temp message with the actual saved message
      final list = List<dynamic>.from(state.activeMessages)
        ..removeWhere((m) => m['id'].toString() == tempMsgId);
      
      if (!list.any((m) => m['id'].toString() == mappedMessage['id'].toString())) {
        list.add(mappedMessage);
      }

      emit(state.copyWith(activeMessages: list));
      _chatCache[userId] = list;

      // Update last message in the thread list locally
      _updateThreadLastMessage(userId, text.isNotEmpty ? text : 'أرسل صورة 📷');

    } catch (e) {
      // Revert optimistic message and show error
      final list = List<dynamic>.from(state.activeMessages)
        ..removeWhere((m) => m['id'].toString() == tempMsgId);
      emit(state.copyWith(activeMessages: list, error: e.toString()));
      _chatCache[userId] = list;
    }
  }

  void _connectSocket() async {
    // ignore: avoid_print
    print('🔌 Admin Chat Socket: attempting to connect for admin $_adminId');
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      } else {
        if (state.selectedUserId != null) {
          _socket!.emit('joinRoom', 'support_${state.selectedUserId}');
        }
        if (_isInComplaintsPage) {
          _socket!.emit('joinRoom', 'complaints_agents');
        }
      }
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
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(99)
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        // ignore: avoid_print
        print('🔌 Admin Chat Socket connected successfully: ${_socket!.id}');
        if (state.selectedUserId != null) {
          _socket!.emit('joinRoom', 'support_${state.selectedUserId}');
          // ignore: avoid_print
          print('📤 Admin Chat Socket emitted auth & joinRoom for support_${state.selectedUserId}');
        }
        if (_isInComplaintsPage) {
          _socket!.emit('joinRoom', 'complaints_agents');
        }
      });

      _socket!.on('typing', (data) {
        // ignore: avoid_print
        print('⌨️ Admin Chat received typing: $data');
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final roomName = mapData['roomName']?.toString();
          if (roomName == 'support_${state.selectedUserId}') {
            final isTyping = mapData['isTyping'] as bool? ?? false;
            emit(state.copyWith(isClientTyping: isTyping));
          }
        }
      });

      _socket!.on('online_users', (data) {
        // ignore: avoid_print
        print('🟢 Admin Chat received online_users: $data');
        if (data is List) {
          final isClientOnline = data.any((uid) => uid.toString() == state.selectedUserId?.toString());
          emit(state.copyWith(isClientOnline: isClientOnline));
        }
      });

      _socket!.on('user_presence', (data) {
        // ignore: avoid_print
        print('👤 Admin Chat received user_presence: $data');
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final presenceUserId = mapData['userId']?.toString();
          final presenceStatus = mapData['status']?.toString();
          if (presenceUserId != null && presenceUserId == state.selectedUserId?.toString()) {
            emit(state.copyWith(isClientOnline: presenceStatus == 'online'));
          }
        }
      });

      _socket!.on('supportMessage', (data) {
        // ignore: avoid_print
        print('📩 Admin Chat received message: $data');
        if (data != null && data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final messageUserId = mapData['userId'] != null ? int.tryParse(mapData['userId'].toString()) : null;
          final senderRole = mapData['senderRole']?.toString();
          
          final formattedMsg = {
            ...mapData,
            'isUser': senderRole == 'admin' || senderRole == 'employee', // in admin panel, admin's messages are isUser = true
          };

          // Cache the message under its thread
          if (messageUserId != null) {
            final cachedList = _chatCache[messageUserId] ?? [];
            if (!cachedList.any((m) => m['id'].toString() == formattedMsg['id'].toString())) {
              _chatCache[messageUserId] = List.from(cachedList)..add(formattedMsg);
            }
          }

          // Check if this message belongs to the currently active chat
          if (messageUserId == state.selectedUserId) {
            if (!state.activeMessages.any((m) => m['id'].toString() == formattedMsg['id'].toString())) {
              final list = List<dynamic>.from(state.activeMessages)..add(formattedMsg);
              emit(state.copyWith(activeMessages: list));
              // Auto-lookup if this is a client message
              if (senderRole != 'admin') {
                autoLookupMessage(formattedMsg);
              }
            }
          }

          // Update unread count and last message in threads list
          if (messageUserId != null) {
            final updatedThreads = state.threads.map((t) {
              if (t['userId'] == messageUserId) {
                final isCurrentActive = messageUserId == state.selectedUserId;
                final newUnread = isCurrentActive 
                    ? 0 
                    : (t['unreadCount'] as int? ?? 0) + (senderRole != 'admin' ? 1 : 0);
                return {
                  ...t,
                  'lastMessage': mapData['text'],
                  'lastMessageTime': mapData['timestamp'] ?? DateTime.now().toIso8601String(),
                  'unreadCount': newUnread,
                };
              }
              return t;
            }).toList();

            // Re-order threads list to put active thread at the top
            updatedThreads.sort((a, b) {
              final aTime = DateTime.tryParse(a['lastMessageTime']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = DateTime.tryParse(b['lastMessageTime']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

            emit(state.copyWith(threads: updatedThreads));
          }
        }
      });

      _socket!.onDisconnect((_) {
        // ignore: avoid_print
        print('🔌 Admin Chat Socket disconnected');
      });

      _socket!.onConnectError((err) {
        // ignore: avoid_print
        print('❌ Admin Chat Socket Error: $err');
      });

      _socket!.connect();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Admin Chat Socket Setup Error: $e');
    }
  }

  void _updateThreadLastMessage(int userId, String text) {
    final updatedThreads = state.threads.map((t) {
      final map = Map<String, dynamic>.from(t as Map);
      if (map['userId'] == userId) {
        return {
          ...map,
          'lastMessage': text,
          'lastMessageTime': DateTime.now().toIso8601String(),
        };
      }
      return map;
    }).toList();

    updatedThreads.sort((a, b) {
      final aTime = DateTime.tryParse(a['lastMessageTime']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['lastMessageTime']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    emit(state.copyWith(threads: updatedThreads));
  }

  @override
  Future<void> close() {
    if (_socket != null) {
      if (state.selectedUserId != null) {
        _socket!.emit('leaveRoom', 'support_${state.selectedUserId}');
      }
      _socket!.disconnect();
      _socket!.destroy();
    }
    return super.close();
  }
}
