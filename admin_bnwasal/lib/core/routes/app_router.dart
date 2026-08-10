import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/home/presentation/cubit/navigation_cubit.dart';
import '../../features/merchants/presentation/cubit/merchants_cubit.dart';
import '../../features/captains/presentation/cubit/captains_cubit.dart';
import '../../features/trips/presentation/cubit/trips_cubit.dart';
import '../../features/pending_accounts/presentation/cubit/pending_accounts_cubit.dart';
import '../../features/complaints/presentation/cubit/complaints_cubit.dart';
import '../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/send_notification/presentation/cubit/send_notification_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/user_messages/presentation/cubit/user_messages_cubit.dart';
import '../di/injection_container.dart' as di;
import 'routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return _buildRoute(const SplashScreen(), settings);
      case Routes.login:
        return _buildRoute(const LoginScreen(), settings);
      case Routes.home:
        return _buildRoute(_buildHome(), settings);
      default:
        return _buildRoute(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static Widget _buildHome() {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: di.sl<DashboardCubit>()),
        BlocProvider.value(value: di.sl<NavigationCubit>()),
        BlocProvider.value(value: di.sl<MerchantsCubit>()),
        BlocProvider.value(value: di.sl<CaptainsCubit>()),
        BlocProvider.value(value: di.sl<TripsCubit>()),
        BlocProvider.value(value: di.sl<PendingAccountsCubit>()),
        BlocProvider.value(value: di.sl<ComplaintsCubit>()),
        BlocProvider.value(value: di.sl<EmployeesCubit>()),
        BlocProvider.value(value: di.sl<NotificationsCubit>()),
        BlocProvider.value(value: di.sl<SendNotificationCubit>()),
        BlocProvider.value(value: di.sl<SettingsCubit>()),
        BlocProvider.value(value: di.sl<UserMessagesCubit>()),
      ],
      child: const HomeScreen(),
    );
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }
}
