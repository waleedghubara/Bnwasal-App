import 'dart:io';
import 'package:easy_localization/easy_localization.dart'
    show BuildContextEasyLocalizationExtension, EasyLocalization;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'core/routes/app_router.dart';
import 'core/routes/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'core/localization/localization_manager.dart';
import 'core/api/api_interceptors.dart';
import 'core/services/notification_service.dart';
import 'core/services/window_tray_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'core/theme/theme_cubit.dart';
import 'core/theme/theme_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (Platform.isWindows) {
    await WindowTrayService().initialize();
  }

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

  // Initialize notification service (Firebase FCM + local notifications)
  final notificationService = NotificationService();
  await notificationService.initialize();

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // If width is >= 600 (tablet/desktop), use the actual screen dimensions as the design size.
        // This stops ScreenUtil from scaling elements up aggressively on desktop/Windows.
        final Size designSize = constraints.maxWidth >= 600
            ? Size(constraints.maxWidth, constraints.maxHeight)
            : const Size(375, 812);

        return ScreenUtilInit(
          designSize: designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: di.sl<AuthCubit>()),
                BlocProvider.value(value: di.sl<SettingsCubit>()),
                BlocProvider.value(value: di.sl<ThemeCubit>()),
              ],
              child: BlocBuilder<ThemeCubit, ThemeState>(
                builder: (context, state) {
                  return MaterialApp(
                    navigatorKey: appNavigatorKey,
                    title: 'بنواصل أدمن',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: state.themeMode,
                    scrollBehavior: AppScrollBehavior(),
                    initialRoute: Routes.splash,
                    builder: (context, child) {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      );
                    },
                    onGenerateRoute: AppRouter.generateRoute,
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    locale: context.locale,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

