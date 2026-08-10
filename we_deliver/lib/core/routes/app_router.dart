// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:we_deliver/features/home/views/home_user.dart';
import 'package:we_deliver/features/main_layout/views/main_layout_screen.dart';
import 'package:we_deliver/features/wallet/presentation/pages/deposit_screen.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/otp_screen.dart';
import '../../features/auth/views/identity_verification_screen.dart';
import '../../features/auth/views/pending_approval_screen.dart';
import '../../features/auth/views/forgot_password_screen.dart';
import '../../features/auth/views/reset_otp_screen.dart';
import '../../features/auth/views/reset_password_screen.dart';
import '../../features/wallet/presentation/pages/wallet_screen.dart';
import '../../features/wallet/presentation/pages/withdraw_screen.dart';
import '../../features/profile/presentation/pages/ratings_screen.dart';
import '../di/injection_container.dart';
import 'routes.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/security_warning_screen.dart';
import '../../features/splash/security_blocked_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/presentation/pages/edit_profile_screen.dart';
import '../../features/profile/presentation/pages/change_password_screen.dart';
import '../../features/profile/presentation/pages/contact_us_screen.dart';
import '../../features/profile/presentation/pages/chat_support_screen.dart';
import '../../features/profile/presentation/pages/refer_earn_screen.dart';
import '../../features/profile/presentation/pages/addresses_screen.dart';
import '../../features/profile/presentation/pages/add_edit_address_screen.dart';
import '../../features/profile/presentation/pages/terms_conditions_screen.dart';
import '../../features/profile/presentation/pages/delivery_prices_screen.dart';
import '../../features/trips/presentation/pages/trips_screen.dart';
import '../../features/trips/presentation/pages/add_trip_screen.dart';
import '../../features/trips/presentation/pages/edit_trip_screen.dart';
import '../../features/home/views/notifications_screen.dart';
import '../../features/home/views/search_screen.dart';
import '../../features/trips/presentation/manager/trip_cubit.dart';
import '../../features/trips/domain/entities/trip.dart';
import '../../features/home/presentation/manager/notification_cubit.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/bloc/address_cubit.dart';
import '../../features/shipment/data/datasources/egypt_locations.dart';
import '../../features/shipment/presentation/pages/offer_inbox_screen.dart';

import '../../features/profile/presentation/bloc/review_cubit.dart';
import '../../features/profile/presentation/bloc/referral_cubit.dart';
import '../../features/profile/presentation/bloc/support_cubit.dart';

/// Application Router
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.securityBlocked:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SecurityBlockedScreen(
            reason: args?['reason'] as String? ?? 'تم حظر التطبيق لأسباب أمنية.',
            solutionSteps: args?['solutionSteps'] as String? ?? 'يرجى مراجعة إعدادات أمان الهاتف الخاص بك.',
          ),
          settings,
        );
      case Routes.securityWarning:

        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SecurityWarningScreen(
            reason: args?['reason'] as String? ?? 'تم اكتشاف بيئة تشغيل غير آمنة.',
          ),
          settings,
        );
      case Routes.splash:
        return _buildRoute(const SplashScreen(), settings);
      case Routes.onboarding:
        return _buildRoute(const OnboardingScreen(), settings);
      case Routes.home:
        return _buildRoute(const HomeUserScreen(), settings);
      case Routes.mainLayout:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          MainLayoutScreen(isDelivery: args?['isDelivery'] ?? false),
          settings,
        );
      case Routes.login:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const LoginScreen(),
          ),
          settings,
        );
      case Routes.register:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const RegisterScreen(),
          ),
          settings,
        );
      case Routes.otp:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: OtpScreen(
              phone: args?['phone'] ?? '',
              otpCode: args?['otpCode'] ?? '',
            ),
          ),
          settings,
        );
      case Routes.identityVerification:
        final args = settings.arguments as Map<String, dynamic>?;
        final stepStr = args?['step'] as String?;
        VerificationStep? initialStep;
        if (stepStr == 'selectVehicle') {
          initialStep = VerificationStep.selectVehicle;
        } else if (stepStr == 'upload') {
          initialStep = VerificationStep.upload;
        }
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: IdentityVerificationScreen(initialStep: initialStep),
          ),
          settings,
        );
      case Routes.pendingApproval:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          PendingApprovalScreen(
            message: args?['message'] as String? ??
                'حسابك قيد المراجعة من قبل الإدارة. يرجى الانتظار حتى يتم التفعيل.',
          ),
          settings,
        );
      case Routes.editProfile:
        return _buildRoute(
          BlocProvider(
            create: (_) => sl<ProfileCubit>()..loadProfile(),
            child: const EditProfileScreen(),
          ),
          settings,
        );
      case Routes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);
      case Routes.resetOtp:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ResetOtpScreen(
            phone: args?['phone'] as String? ?? '',
            resetOtp: args?['resetOtp'] as String? ?? '',
          ),
          settings,
        );
      case Routes.resetPassword:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ResetPasswordScreen(
            resetToken: args?['resetToken'] as String? ?? '',
          ),
          settings,
        );
      case Routes.changePassword:
        return _buildRoute(
          BlocProvider(
            create: (_) => sl<ProfileCubit>(),
            child: const ChangePasswordScreen(),
          ),
          settings,
        );
      case Routes.contactUs:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<SupportCubit>(),
            child: const ContactUsScreen(),
          ),
          settings,
        );
      case Routes.chatSupport:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<SupportCubit>()..initSupportChat(),
            child: const ChatSupportScreen(),
          ),
          settings,
        );
      case Routes.negotiationChat:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          OfferInboxScreen(
            shipmentId: args?['shipmentId'] as String?,
            orderId: args?['orderId'] as String?,
            number: args?['number'] as String? ?? '',
            title: args?['title'] as String? ?? '',
            price: args?['price'] as double? ?? 0.0,
          ),
          settings,
        );
      case Routes.referEarn:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<ReferralCubit>()..loadReferralSummary(),
            child: const ReferEarnScreen(),
          ),
          settings,
        );
      case Routes.addresses:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AddressCubit>()..loadAddresses(),
            child: const AddressesScreen(),
          ),
          settings,
        );
      case Routes.deliveryPrices:
        return _buildRoute(const DeliveryPricesScreen(), settings);
      case Routes.addAddress:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AddressCubit>(),
            child: const AddEditAddressScreen(),
          ),
          settings,
        );
      case Routes.editAddress:
        final address = settings.arguments as SavedAddress?;
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AddressCubit>(),
            child: AddEditAddressScreen(isEdit: true, address: address),
          ),
          settings,
        );
      case Routes.wallet:
        return _buildRoute(const WalletScreen(), settings);
      case Routes.deposit:
        return _buildRoute(const DepositScreen(), settings);
      case Routes.withdraw:
        return _buildRoute(const WithdrawScreen(), settings);
      case Routes.ratings:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<ReviewCubit>()..loadReviews(),
            child: const RatingsScreen(),
          ),
          settings,
        );
      case Routes.trips:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<TripCubit>()..loadTrips(),
            child: const TripsScreen(),
          ),
          settings,
        );
      case Routes.addTrip:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<TripCubit>(),
            child: const AddTripScreen(),
          ),
          settings,
        );
      case Routes.editTrip:
        final trip = settings.arguments as Trip;
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<TripCubit>(),
            child: EditTripScreen(trip: trip),
          ),
          settings,
        );
      case Routes.termsConditions:
        return _buildRoute(const TermsConditionsScreen(), settings);
      case Routes.notifications:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<NotificationCubit>()..loadNotifications(),
            child: const NotificationsScreen(),
          ),
          settings,
        );
      case Routes.search:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SearchScreen(isDelivery: args?['isDelivery'] ?? false),
          settings,
        );
      default:
        return _buildRoute(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings,
        );
    }
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
