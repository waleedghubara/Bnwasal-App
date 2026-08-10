import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../network/network_info.dart';
import '../api/api_interceptors.dart';
import '../api/dio_consumer.dart';
import '../config/app_config.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/dashboard/data/dashboard_api.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/home/presentation/cubit/navigation_cubit.dart';
import '../../features/merchants/data/merchants_api.dart';
import '../../features/merchants/presentation/cubit/merchants_cubit.dart';
import '../../features/captains/data/captains_api.dart';
import '../../features/captains/presentation/cubit/captains_cubit.dart';
import '../../features/trips/data/trips_api.dart';
import '../../features/trips/presentation/cubit/trips_cubit.dart';
import '../../features/pending_accounts/data/pending_accounts_api.dart';
import '../../features/pending_accounts/presentation/cubit/pending_accounts_cubit.dart';
import '../../features/complaints/data/complaints_api.dart';
import '../../features/complaints/presentation/cubit/complaints_cubit.dart';
import '../../features/employees/data/employees_api.dart';
import '../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../features/notifications/data/notifications_api.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/send_notification/data/send_notification_api.dart';
import '../../features/send_notification/presentation/cubit/send_notification_cubit.dart';
import '../../features/settings/data/settings_api.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/settings/presentation/cubit/payment_methods_cubit.dart';
import '../../features/user_messages/data/user_messages_api.dart';
import '../../features/user_messages/presentation/cubit/user_messages_cubit.dart';
import '../theme/theme_cubit.dart';
import '../cache/cache_helper.dart';

final sl = GetIt.instance;

/// Initialize Dependency Injection
Future<void> init() async {
  //! Core Theme
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(SecureCacheHelper()));

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! External
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  sl.registerLazySingleton(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(ApiInterceptor());

    if (AppConfig.enableLogging) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return dio;
  });

  sl.registerLazySingleton<DioConsumer>(() => DioConsumer(dio: sl()));

  //! Auth Feature
  sl.registerLazySingleton<AuthApi>(() => AuthApi(sl()));
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl(), sl()));

  //! Dashboard Feature
  sl.registerLazySingleton<DashboardApi>(() => DashboardApi(sl()));
  sl.registerLazySingleton<DashboardCubit>(() => DashboardCubit(sl()));

  //! Merchants Feature
  sl.registerLazySingleton<MerchantsApi>(() => MerchantsApi(sl()));
  sl.registerLazySingleton<MerchantsCubit>(() => MerchantsCubit(sl()));

  //! Captains Feature
  sl.registerLazySingleton<CaptainsApi>(() => CaptainsApi(sl()));
  sl.registerLazySingleton<CaptainsCubit>(() => CaptainsCubit(sl(), sl()));

  //! Trips Feature
  sl.registerLazySingleton<TripsApi>(() => TripsApi(sl()));
  sl.registerLazySingleton<TripsCubit>(() => TripsCubit(sl()));

  //! Pending Accounts Feature
  sl.registerLazySingleton<PendingAccountsApi>(() => PendingAccountsApi(sl()));
  sl.registerLazySingleton<PendingAccountsCubit>(() => PendingAccountsCubit(sl()));

  //! Complaints Feature
  sl.registerLazySingleton<ComplaintsApi>(() => ComplaintsApi(sl()));
  sl.registerLazySingleton<ComplaintsCubit>(() => ComplaintsCubit(sl()));

  //! Employees Feature
  sl.registerLazySingleton<EmployeesApi>(() => EmployeesApi(sl()));
  sl.registerLazySingleton<EmployeesCubit>(() => EmployeesCubit(sl()));

  //! Notifications Feature
  sl.registerLazySingleton<NotificationsApi>(() => NotificationsApi(sl()));
  sl.registerLazySingleton<NotificationsCubit>(() => NotificationsCubit(sl()));

  //! Send Notification Feature
  sl.registerLazySingleton<SendNotificationApi>(() => SendNotificationApi(sl()));
  sl.registerLazySingleton<SendNotificationCubit>(() => SendNotificationCubit(sl()));

  //! Settings Feature
  sl.registerLazySingleton<SettingsApi>(() => SettingsApi(sl()));
  sl.registerLazySingleton<SettingsCubit>(() => SettingsCubit(sl()));
  sl.registerFactory<PaymentMethodsCubit>(() => PaymentMethodsCubit(sl()));

  //! User Messages Feature
  sl.registerLazySingleton<UserMessagesApi>(() => UserMessagesApi(sl()));
  sl.registerLazySingleton<UserMessagesCubit>(() => UserMessagesCubit(sl()));

  //! Home Feature
  sl.registerLazySingleton<NavigationCubit>(() => NavigationCubit());
}
