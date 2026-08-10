// ignore_for_file: unused_import, unused_field

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io_socket;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:admin_bnwasal/firebase_options.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/cache/cache_helper.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/utils/text_sanitizer.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final service = NotificationService();
  await service._initLocalNotifications();
  await service._showLocalNotification(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  bool _initialized = false;
  String? _fcmToken;
  io_socket.Socket? _socket;
  VoidCallback? onDashboardUpdate;
  final List<VoidCallback> _dashboardUpdateListeners = [];
  void Function(Map<String, dynamic>)? onLocationUpdate;
  String? _pendingUserId;

  final List<void Function(Map<String, dynamic>)> _orderCreatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _orderUpdatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _shipmentCreatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _shipmentUpdatedListeners = [];

  String? get fcmToken => _fcmToken;
  io_socket.Socket? get socket => _socket;

  void addDashboardUpdateListener(VoidCallback listener) {
    if (!_dashboardUpdateListeners.contains(listener)) {
      _dashboardUpdateListeners.add(listener);
    }
  }

  void removeDashboardUpdateListener(VoidCallback listener) {
    _dashboardUpdateListeners.remove(listener);
  }

  void addOrderCreatedListener(void Function(Map<String, dynamic>) listener) {
    if (!_orderCreatedListeners.contains(listener)) _orderCreatedListeners.add(listener);
  }
  void removeOrderCreatedListener(void Function(Map<String, dynamic>) listener) {
    _orderCreatedListeners.remove(listener);
  }

  void addOrderUpdatedListener(void Function(Map<String, dynamic>) listener) {
    if (!_orderUpdatedListeners.contains(listener)) _orderUpdatedListeners.add(listener);
  }
  void removeOrderUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _orderUpdatedListeners.remove(listener);
  }

  void addShipmentCreatedListener(void Function(Map<String, dynamic>) listener) {
    if (!_shipmentCreatedListeners.contains(listener)) _shipmentCreatedListeners.add(listener);
  }
  void removeShipmentCreatedListener(void Function(Map<String, dynamic>) listener) {
    _shipmentCreatedListeners.remove(listener);
  }

  void addShipmentUpdatedListener(void Function(Map<String, dynamic>) listener) {
    if (!_shipmentUpdatedListeners.contains(listener)) _shipmentUpdatedListeners.add(listener);
  }
  void removeShipmentUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _shipmentUpdatedListeners.remove(listener);
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'we_deliver_alerts_v1',
    'إشعارات بنواصل',
    description: 'قناة الإشعارات الرئيسية لتطبيق بنواصل',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('app_notification'),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}

    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint('❌ NotificationService: Failed to initialize local notifications: $e');
    }

    if (Platform.isAndroid) {
      try {
        await _initFcm();
      } catch (e) {
        debugPrint('❌ NotificationService: Failed to initialize FCM: $e');
      }
    }

    _connectSocket();
    _initialized = true;
  }

  void connectSocket() {
    _connectSocket();
  }

  void disconnectSocket() {
    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
  }

  Future<void> _initFcm() async {
    try {
      _messaging = FirebaseMessaging.instance;
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _fcmToken = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _sendTokenToServer(token);
      });
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (_) {}
  }

  void _connectSocket() async {
    try {
      if (_socket != null) {
        try {
          _socket!.disconnect();
          _socket!.dispose();
        } catch (_) {}
        _socket = null;
      }

      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      if (token == null || token.isEmpty) {
        debugPrint('🔌 Socket connection skipped: Token is empty');
        return;
      }

      _socket = io_socket.io(
        EndPoint.socketUrl,
        io_socket.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setAuth({'token': token})
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(99)
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('🔌 Socket connected successfully: ${_socket!.id}');
        _socket!.emit('join_admin_room');
      });

      _socket!.on('notification', (data) {
        debugPrint('📩 Socket event [notification] received: $data');
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        if (data is Map) {
          showLocalNotification(
            sanitizeText(data['title']?.toString()),
            sanitizeText(data['body']?.toString()),
          );
        }
      });

      _socket!.on('dashboard_update', (_) {
        debugPrint('🔄 Socket event [dashboard_update] received');
        for (final listener in List<VoidCallback>.from(
          _dashboardUpdateListeners,
        )) {
          try {
            listener();
          } catch (e) {
            debugPrint('Error calling dashboard update listener: $e');
          }
        }
        onDashboardUpdate?.call();
      });

      _socket!.on('locationUpdate', (data) {
        debugPrint('📍 Socket event [locationUpdate] received: $data');
        if (data is Map) {
          onLocationUpdate?.call(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('order_created', (data) {
        debugPrint('📦 Socket event [order_created] received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final listener in List<void Function(Map<String, dynamic>)>.from(_orderCreatedListeners)) {
            try {
              listener(map);
            } catch (e) {
              debugPrint('Error calling order_created listener: $e');
            }
          }
        }
      });

      _socket!.on('order_updated', (data) {
        debugPrint('🔄 Socket event [order_updated] received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final listener in List<void Function(Map<String, dynamic>)>.from(_orderUpdatedListeners)) {
            try {
              listener(map);
            } catch (e) {
              debugPrint('Error calling order_updated listener: $e');
            }
          }
        }
      });

      _socket!.on('shipment_created', (data) {
        debugPrint('🚚 Socket event [shipment_created] received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final listener in List<void Function(Map<String, dynamic>)>.from(_shipmentCreatedListeners)) {
            try {
              listener(map);
            } catch (e) {
              debugPrint('Error calling shipment_created listener: $e');
            }
          }
        }
      });

      _socket!.on('shipment_updated', (data) {
        debugPrint('🔄 Socket event [shipment_updated] received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final listener in List<void Function(Map<String, dynamic>)>.from(_shipmentUpdatedListeners)) {
            try {
              listener(map);
            } catch (e) {
              debugPrint('Error calling shipment_updated listener: $e');
            }
          }
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('🔌 Socket disconnected');
      });

      _socket!.onConnectError((err) {
        debugPrint('❌ Socket connection error: $err');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('🔌 Socket connection exception: $e');
    }
  }

  void setSocketUserId(String userId) {
    _pendingUserId = userId;
  }

  void joinRoom(String roomName) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('joinRoom', roomName);
    }
  }

  void leaveRoom(String roomName) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leaveRoom', roomName);
    }
  }

  static String? _cachedIconPath;

  Future<String> _getIconPath() async {
    if (_cachedIconPath != null) return _cachedIconPath!;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/icon.ico');
    if (!await file.exists()) {
      final byteData = await rootBundle.load('assets/images/icon.ico');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    }
    _cachedIconPath = file.path;
    return _cachedIconPath!;
  }

  static String? _cachedLogoPngPath;

  Future<String> _getLogoPngPath() async {
    if (_cachedLogoPngPath != null) return _cachedLogoPngPath!;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/logo.jpeg');
    if (!await file.exists()) {
      try {
        final byteData = await rootBundle.load('assets/images/logo.jpeg');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
      } catch (e) {
        debugPrint('Error writing app_logo.png: $e');
      }
    }
    _cachedLogoPngPath = file.path;
    return _cachedLogoPngPath!;
  }

  Future<void> _initLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      String? winIconPath;
      if (Platform.isWindows) {
        try {
          winIconPath = await _getIconPath();
          await _getLogoPngPath(); // Pre-cache PNG logo
        } catch (e) {
          debugPrint('Error getting Windows notification assets: $e');
        }
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'فتح');
      final winSettings = WindowsInitializationSettings(
        appName: 'بنواصل',
        appUserModelId: 'com.bnwasal.admin',
        guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        iconPath: winIconPath,
      );

      await _localNotifications!.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          linux: linuxSettings,
          windows: winSettings,
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      try {
        await _localNotifications!
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_channel);
      } catch (_) {}
    } catch (e, stack) {
      debugPrint('❌ Error initializing local notifications: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  static String? _cachedSoundPath;

  Future<String> _getSoundPath() async {
    if (_cachedSoundPath != null) return _cachedSoundPath!;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/app_notification.wav');
    if (!await file.exists()) {
      final byteData = await rootBundle.load(
        'assets/icons/app_notification.wav',
      );
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    }
    _cachedSoundPath = file.path;
    return _cachedSoundPath!;
  }

  void _playNotificationSound() async {
    if (!Platform.isWindows) return;
    try {
      final path = await _getSoundPath();
      final pathPtr = path.toNativeUtf16();
      PlaySound(pathPtr, NULL, SND_FILENAME | SND_ASYNC);
      free(pathPtr);
    } catch (e) {
      debugPrint('Error playing notification sound via Win32: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {}

  void _onLocalNotificationTap(NotificationResponse response) {}

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? '';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;
    _playNotificationSound();
    final id = DateTime.now().millisecondsSinceEpoch % 100000;

    WindowsNotificationDetails? winDetails;
    if (Platform.isWindows) {
      try {
        final logoPath = await _getLogoPngPath();
        winDetails = WindowsNotificationDetails(
          images: [
            WindowsImage(
              Uri.file(logoPath, windows: true),
              altText: 'Logo',
              placement: WindowsImagePlacement.appLogoOverride,
            ),
          ],
        );
      } catch (e) {
        debugPrint('Error getting Windows notification details: $e');
      }
    }

    try {
      await _localNotifications?.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'we_deliver_alerts_v1',
            'إشعارات بنواصل',
            channelDescription: 'قناة الإشعارات الرئيسية لتطبيق بنواصل',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            sound: const RawResourceAndroidNotificationSound(
              'app_notification',
            ),
          ),
          iOS: DarwinNotificationDetails(),
          windows: winDetails,
        ),
      );
    } catch (_) {}
  }

  Future<void> showLocalNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    _playNotificationSound();
    final id = DateTime.now().millisecondsSinceEpoch % 100000;

    WindowsNotificationDetails? winDetails;
    if (Platform.isWindows) {
      try {
        final logoPath = await _getLogoPngPath();
        winDetails = WindowsNotificationDetails(
          images: [
            WindowsImage(
              Uri.file(logoPath, windows: true),
              altText: 'Logo',
              placement: WindowsImagePlacement.appLogoOverride,
            ),
          ],
        );
      } catch (e) {
        debugPrint('Error getting Windows notification details: $e');
      }
    }

    try {
      await _localNotifications?.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'we_deliver_messages',
            'إشعارات بنواصل',
            channelDescription: 'قناة الإشعارات الرئيسية',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            sound: const RawResourceAndroidNotificationSound(
              'app_notification',
            ),
          ),
          iOS: DarwinNotificationDetails(),
          windows: winDetails,
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  void _sendTokenToServer(String token) {
    try {
      _doSendToken(token);
    } catch (_) {}
  }

  Future<void> _doSendToken(String token) async {
    try {
      final dio = di.sl<DioConsumer>();
      await dio.put(EndPoint.updateFcmToken, data: {'fcmToken': token});
    } catch (_) {}
  }
}
