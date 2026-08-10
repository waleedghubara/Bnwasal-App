// ignore_for_file: avoid_print

import 'package:easy_localization/easy_localization.dart'
    show EasyLocalization, BuildContextEasyLocalizationExtension;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:we_deliver/core/localization/localization_manager.dart'
    show LocalizationManager;

import 'core/routes/app_router.dart';
import 'core/routes/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/notifications/notification_service.dart';
import 'core/services/security_guard.dart';
import 'features/splash/security_blocked_screen.dart';
import 'core/services/firebase_config_service.dart';
import 'core/services/location_service.dart';
import 'core/services/appsflyer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CRITICAL: This MUST be a top-level function, registered BEFORE Firebase.initializeApp()
// It handles FCM messages when the app is terminated or in the background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized when this runs — no need to reinitialize.
  await NotificationService.showSystemNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run security checks before ANY service initializes
  final securityStatus = await SecurityGuard.checkSecurity();
  if (securityStatus == SecurityStatus.blocked) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SecurityBlockedScreen(
          reason: SecurityGuard.blockReason ?? 'تم حظر التطبيق لأسباب أمنية.',
          solutionSteps: SecurityGuard.solutionSteps ?? 'يرجى مراجعة إعدادات أمان الهاتف الخاص بك.',
          onRetrySuccess: () async {
            await _initializeAndRunApp();
          },
        ),
      ),
    );
    return; // Stop initialization completely!
  }

  await _initializeAndRunApp();
}

Future<void> _initializeAndRunApp() async {
  await EasyLocalization.ensureInitialized();

  // MUST register background handler BEFORE Firebase.initializeApp()
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseConfigService.initialize();
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependency injection
  await di.init();

  // Initialize AppsFlyer Service
  try {
    await di.sl<AppsFlyerService>().init();
  } catch (e) {
    print('❌ AppsFlyer initialization failed: $e');
  }

  // Initialize location tracking automatically
  try {
    await di.sl<LocationService>().initializeLocationTracking();
  } catch (e) {
    print('❌ Location tracking initialization failed: $e');
  }

  // Initialize Notification Service
  try {
    await di.sl<NotificationService>().init();
  } catch (e) {
    print('❌ Notification initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: LocalizationManager.supportedLocales,
      path: LocalizationManager.translationsPath,
      fallbackLocale: LocalizationManager.fallbackLocale,
      startLocale: LocalizationManager.fallbackLocale,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'بنوصل',
          navigatorKey: NotificationService.navigatorKey,
          scaffoldMessengerKey: NotificationService.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // darkTheme: AppTheme.darkTheme,
          // themeMode: ThemeMode.system,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          initialRoute: Routes.splash,
          onGenerateRoute: AppRouter.generateRoute,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}


//  builder: (context, child) {
//             final notifications = sl<NotificationService>();
//             return Directionality(
//               textDirection: TextDirection.rtl,
//               child: MediaQuery(
//                 data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
//                 child: child!,
//               ),
//             );
//           },