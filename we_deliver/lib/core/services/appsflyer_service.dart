import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/material.dart';
import 'package:we_deliver/core/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';

abstract class AppsFlyerService {
  Future<void> init();
  Future<bool?> logEvent(String eventName, Map<dynamic, dynamic>? eventValues);
  Future<void> setCustomerUserId(String userId);
  Future<void> setUserEmail(String email);
}

class AppsFlyerServiceImpl implements AppsFlyerService {
  AppsflyerSdk? _appsflyerSdk;

  void _showDebugDialog({
    required bool success,
    required String title,
    required String message,
  }) {
    if (!kDebugMode) return;
    
    // Delay to ensure MaterialApp context is fully built and screen is settled
    Future.delayed(const Duration(seconds: 5), () {
      final context = NotificationService.navigatorKey.currentContext;
      if (context == null) {
        debugPrint('[AppsFlyerService] Cannot show debug dialog: context is null');
        return;
      }
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.warning_rounded,
                    color: success ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'حسناً',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Future<void> init() async {
    try {
      const devKey = String.fromEnvironment('APPSFLYER_DEV_KEY', defaultValue: '');
      const appId = String.fromEnvironment('APP_ID', defaultValue: '');

      if (devKey.isEmpty) {
        debugPrint('[AppsFlyerService] APPSFLYER_DEV_KEY is empty in Environment variables. Skipping initialization.');
        if (kDebugMode) {
          // Show Toast-like SnackBar fallback
          Future.delayed(const Duration(seconds: 4), () {
            NotificationService.scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ تنبيه AppsFlyer: المفتاح فارغ في بيئة التطوير.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          });
          // Show dialog popup
          _showDebugDialog(
            success: false,
            title: 'تنبيه AppsFlyer',
            message: 'لم يتم تهيئة AppsFlyer لأن APPSFLYER_DEV_KEY فارغ في متغيرات البيئة.\n\nتأكد من تشغيل التطبيق باستخدام الخيار:\n--dart-define=APPSFLYER_DEV_KEY=YOUR_KEY',
          );
        }
        return;
      }

      final AppsFlyerOptions options = AppsFlyerOptions(
        afDevKey: devKey,
        appId: appId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 15,
      );

      _appsflyerSdk = AppsflyerSdk(options);
      
      final result = await _appsflyerSdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );

      debugPrint('[AppsFlyerService] Initialized successfully. AppID: $appId, Result: $result');

      if (kDebugMode) {
        // Show Toast-like SnackBar fallback
        Future.delayed(const Duration(seconds: 4), () {
          NotificationService.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                '🟢 تم تهيئة AppsFlyer بنجاح!',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        });
        // Show dialog popup
        _showDebugDialog(
          success: true,
          title: 'نجاح AppsFlyer',
          message: 'تم تهيئة AppsFlyer بنجاح والمفتاح متصل وجاهز للاستخدام! ✅',
        );
      }
    } catch (e) {
      debugPrint('[AppsFlyerService] Failed to initialize AppsFlyer: $e');
      if (kDebugMode) {
        // Show Toast-like SnackBar fallback
        Future.delayed(const Duration(seconds: 4), () {
          NotificationService.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                '🔴 فشل تهيئة AppsFlyer: $e',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        });
        // Show dialog popup
        _showDebugDialog(
          success: false,
          title: 'خطأ AppsFlyer',
          message: 'فشل تهيئة AppsFlyer:\n$e',
        );
      }
    }
  }

  @override
  Future<bool?> logEvent(String eventName, Map<dynamic, dynamic>? eventValues) async {
    if (_appsflyerSdk == null) {
      debugPrint('[AppsFlyerService] SDK is not initialized. Skipping event log: $eventName');
      return false;
    }
    try {
      debugPrint('[AppsFlyerService] Logging event: $eventName with parameters: $eventValues');
      return await _appsflyerSdk!.logEvent(eventName, eventValues);
    } catch (e) {
      debugPrint('[AppsFlyerService] Error logging event $eventName to AppsFlyer: $e');
      return false;
    }
  }

  @override
  Future<void> setCustomerUserId(String userId) async {
    if (_appsflyerSdk == null) return;
    try {
      _appsflyerSdk!.setCustomerUserId(userId);
      debugPrint('[AppsFlyerService] setCustomerUserId success: $userId');
    } catch (e) {
      debugPrint('[AppsFlyerService] Error setting Customer User ID: $e');
    }
  }

  @override
  Future<void> setUserEmail(String email) async {
    if (_appsflyerSdk == null) return;
    try {
      _appsflyerSdk!.setUserEmails([email]);
      debugPrint('[AppsFlyerService] setUserEmails success: $email');
    } catch (e) {
      debugPrint('[AppsFlyerService] Error setting User Emails: $e');
    }
  }
}
