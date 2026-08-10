// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/shipment/domain/usecases/update_fcm_token_usecase.dart';
import '../routes/routes.dart';
import '../cache/cache_helper.dart';
import '../api/end_point.dart';
import '../utils/text_sanitizer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background FCM Handler — must be a top-level function (not inside a class).
// Registered in main.dart BEFORE Firebase.initializeApp().
// Runs in an isolated Dart context when the app is killed or in background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showSystemNotification(message);
}

@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    final parts = payload.split('|');
    final firstPart = parts[0];
    if (firstPart == 'support') {
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService.navigatorKey.currentState?.pushNamed(
          Routes.chatSupport,
        );
      });
      return;
    }
    // type|shipmentId|orderId|number|title|price
    final type = firstPart;
    if (type == 'price_offer' || type == 'negotiation') {
      final shipmentId = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1]
          : null;
      final orderId = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
      final number = parts.length > 3 ? parts[3] : '';
      final title = parts.length > 4 ? parts[4] : '';
      final price = parts.length > 5 ? (double.tryParse(parts[5]) ?? 0.0) : 0.0;
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService.navigatorKey.currentState?.pushNamed(
          Routes.negotiationChat,
          arguments: {
            'shipmentId': shipmentId,
            'orderId': orderId,
            'number': number,
            'title': title,
            'price': price,
          },
        );
      });
    }
    // Other types: no navigation (status updates, etc.)
  }
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static bool isChatSupportScreenActive = false;

  // ─── Flutter Local Notifications plugin (singleton) ───────────────────────
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel IDs — must match AndroidManifest meta-data
  static const String _channelId = 'we_deliver_alerts_v1';
  static const String _channelName = 'رسائل التوصيل';
  static const String _channelDesc = 'إشعارات الرسائل ومتابعة الشحنات';

  // Global Keys for context-free navigation & snackbar
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final UpdateFcmTokenUseCase _updateFcmTokenUseCase;

  NotificationService(this._updateFcmTokenUseCase);

  // ─────────────────────────────────────────────────────────────────────────
  // Public: Initialize everything
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // NOTE: FirebaseMessaging.onBackgroundMessage() is registered in main.dart
    // BEFORE Firebase.initializeApp() — do NOT register it here.

    // 1. Set up flutter_local_notifications with channel + custom sound
    await _initLocalNotifications();

    // 3. Request FCM permission
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 Notification permission: GRANTED');
    } else {
      print('⚠️ Notification permission: ${settings.authorizationStatus}');
    }

    // 3. On Android: Allow FCM to also present foreground notifications natively
    //    (acts as a safety net when flutter_local_notifications fails)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Sync FCM token to backend
    await syncToken();

    // 6. Token refresh listener
    _fcm.onTokenRefresh.listen((token) async {
      print('🔄 FCM Token Refreshed: $token');
      try {
        final authToken = await SecureCacheHelper().getData(key: ApiKey.token);
        if (authToken != null && authToken.isNotEmpty) {
          await _updateFcmTokenUseCase(token);
        } else {
          print(
            '🔄 FCM Token Refreshed but user is not logged in. Skipping upload.',
          );
        }
      } catch (e) {
        print('❌ Failed to refresh FCM token: $e');
      }
    });

    // 7. Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground FCM: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // 8. Background → foreground tap listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📲 Tapped notification (background): ${message.messageId}');
      _handleNotificationClick(message);
    });

    // 9. App terminated → opened from notification
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      print('📲 Tapped notification (terminated): ${initialMessage.messageId}');
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationClick(initialMessage);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private: Set up flutter_local_notifications + Android channel with sound
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onForegroundNotificationTap,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
    );

    // Create high-importance Android channel with custom sound
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('app_notification'),
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print('🔔 Notification channel ready: $_channelId (with custom sound)');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public static: Show a system-tray notification (works from isolates too)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> showSystemNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final String title =
        notification?.title ?? data['title']?.toString() ?? 'إشعار جديد';
    final String body =
        notification?.body ??
        data['text']?.toString() ??
        data['body']?.toString() ??
        '';
    final String? shipmentId = data['shipmentId']?.toString();
    final String? type = data['type']?.toString();
    final String? orderId = data['orderId']?.toString();
    final String? number = data['number']?.toString();
    final String? itemTitle = data['title']?.toString();
    final String? priceStr = data['price']?.toString();

    // Build payload depending on notification type
    // price_offer/negotiation: "type|shipmentId|orderId|number|title|price"
    // support: "support"
    // others: (no navigation needed)
    final String payload;
    if (type == 'support_message') {
      payload = 'support';
    } else if (type == 'price_offer' || type == 'negotiation') {
      payload = [
        type,
        shipmentId ?? '',
        orderId ?? '',
        number ?? '',
        itemTitle ?? title,
        priceStr ?? '0',
      ].join('|');
    } else {
      payload = '';
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('app_notification'),
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'app_notification.wav',
      ),
    );

    // Ensure plugin is initialized in background isolate
    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onForegroundNotificationTap,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
      );
    } catch (_) {
      // Already initialized, continue
    }

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification tap callbacks
  // ─────────────────────────────────────────────────────────────────────────
  static void _onForegroundNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final firstPart = parts[0];
    if (firstPart == 'support') {
      navigatorKey.currentState?.pushNamed(Routes.chatSupport);
      return;
    }
    // type|shipmentId|orderId|number|title|price
    if (firstPart == 'price_offer' || firstPart == 'negotiation') {
      final shipmentId = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1]
          : null;
      final orderId = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
      final number = parts.length > 3 ? parts[3] : '';
      final title = parts.length > 4 ? parts[4] : '';
      final price = parts.length > 5 ? (double.tryParse(parts[5]) ?? 0.0) : 0.0;
      navigatorKey.currentState?.pushNamed(
        Routes.negotiationChat,
        arguments: {
          'shipmentId': shipmentId,
          'orderId': orderId,
          'number': number,
          'title': title,
          'price': price,
        },
      );
    }
    // Other types: no navigation
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token management
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> syncToken() async {
    try {
      final authToken = await SecureCacheHelper().getData(key: ApiKey.token);
      if (authToken == null || authToken.isEmpty) {
        print('🔔 FCM Sync: No auth token found. Skipping FCM token sync.');
        return;
      }
      final String? token = await _fcm.getToken();
      if (token != null) {
        print('🔔 FCM Token: $token');
        await _updateFcmTokenUseCase(token);
      }
    } catch (e) {
      print('❌ Failed to sync FCM token: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Foreground: show system notification + optional in-app banner
  // ─────────────────────────────────────────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final String? type = data['type']?.toString();
    final String? shipmentId = data['shipmentId']?.toString();
    final String? orderId = data['orderId']?.toString();
    final String? number = data['number']?.toString();
    final String? itemTitle = data['title']?.toString();
    final double? price = double.tryParse(data['price']?.toString() ?? '');
    final String senderName =
        data['senderName'] as String? ??
        message.notification?.title ??
        'إشعار جديد';
    final String text =
        data['text'] as String? ??
        data['body'] as String? ??
        message.notification?.body ??
        '';
    final String? senderAvatar = data['senderAvatar']?.toString();

    // Suppress if support message and support chat screen is active
    if (type == 'support_message' && isChatSupportScreenActive) {
      print('🟢 Inside support chat — suppressing notification.');
      return;
    }

    // Show system tray notification with custom sound
    showSystemNotification(message);

    // Haptic feedback
    _triggerVibration();

    // Show premium in-app banner from the TOP
    _showInAppBanner(
      senderName,
      text,
      shipmentId,
      senderAvatar,
      type,
      orderId: orderId,
      number: number,
      itemTitle: itemTitle,
      price: price,
    );
  }

  void _triggerVibration() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Vibration error: $e');
    }
  }

  void _showInAppBanner(
    String title,
    String body,
    String? shipmentId,
    String? avatarUrl,
    String? type, {
    String? orderId,
    String? number,
    String? itemTitle,
    double? price,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBannerOverlay(
        title: title,
        body: body,
        avatarUrl: avatarUrl,
        onTap: () {
          entry.remove();
          if (type == 'support_message') {
            navigatorKey.currentState?.pushNamed(Routes.chatSupport);
          } else if (type == 'price_offer' || type == 'negotiation') {
            navigatorKey.currentState?.pushNamed(
              Routes.negotiationChat,
              arguments: {
                'shipmentId': shipmentId,
                'orderId': orderId,
                'number': number ?? '',
                'title': itemTitle ?? title,
                'price': price ?? 0.0,
              },
            );
          }
          // Other types: just dismiss
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlayState.insert(entry);
  }

  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final String? type = data['type']?.toString();
    final String? shipmentId = data['shipmentId']?.toString();
    final String? orderId = data['orderId']?.toString();
    final String? number = data['number']?.toString();
    final String? itemTitle = data['title']?.toString();
    final double? price = double.tryParse(data['price']?.toString() ?? '');

    if (type == 'support_message') {
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushNamed(Routes.chatSupport);
      });
      return;
    }

    if (type == 'price_offer' || type == 'negotiation') {
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushNamed(
          Routes.negotiationChat,
          arguments: {
            'shipmentId': shipmentId,
            'orderId': orderId,
            'number': number ?? '',
            'title': itemTitle ?? '',
            'price': price ?? 0.0,
          },
        );
      });
    }
    // Other types (status updates, etc.) → no navigation needed
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-of-screen in-app notification banner (uses Overlay, slides from top)
// ─────────────────────────────────────────────────────────────────────────────
class _TopBannerOverlay extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _TopBannerOverlay({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    this.avatarUrl,
  });

  @override
  State<_TopBannerOverlay> createState() => _TopBannerOverlayState();
}

class _TopBannerOverlayState extends State<_TopBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A7A), Color(0xFF1F4C9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F4C9B).withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Avatar / icon
                            _buildAvatar(),
                            const SizedBox(width: 12),
                            // Text content
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sanitizeText(widget.title),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.tajawal(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'الآن',
                                          style: GoogleFonts.tajawal(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sanitizeText(widget.body),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dismiss X button
                            GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white24,
        backgroundImage: NetworkImage(widget.avatarUrl!),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }
    final initial = widget.title.isNotEmpty
        ? widget.title[0].toUpperCase()
        : '؟';
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white24,
      child: Text(
        initial,
        style: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
