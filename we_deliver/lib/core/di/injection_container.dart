// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../services/location_service.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import '../network/network_info.dart';
import '../api/api_interceptors.dart';
import '../config/app_config.dart';
import '../../features/shipment/data/datasources/shipment_remote_data_source.dart';
import '../../features/shipment/data/repositories/shipment_repository_impl.dart';
import '../../features/shipment/domain/repositories/shipment_repository.dart';
import '../../features/shipment/domain/usecases/get_shipments_usecase.dart';
import '../../features/shipment/domain/usecases/add_shipment_usecase.dart';
import '../../features/shipment/domain/usecases/update_shipment_status_usecase.dart';
import '../../features/shipment/domain/usecases/get_shipment_by_id_usecase.dart';
import '../../features/shipment/domain/usecases/get_messages_usecase.dart';
import '../../features/shipment/domain/usecases/send_message_usecase.dart';
import '../../features/shipment/domain/usecases/update_fcm_token_usecase.dart';
import '../../features/shipment/presentation/manager/chat_cubit.dart';
import '../notifications/notification_service.dart';
import '../../features/order/data/datasources/order_remote_data_source.dart';
import '../../features/order/data/repositories/order_repository_impl.dart';
import '../../features/order/domain/repositories/order_repository.dart';
import '../../features/order/domain/usecases/create_order_usecase.dart';
import '../../features/order/domain/usecases/get_orders_usecase.dart';
import '../../features/order/domain/usecases/update_order_status_usecase.dart';
import '../../features/order/domain/usecases/get_order_by_id_usecase.dart';
import '../../features/order/presentation/manager/order_cubit.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../api/api_consumer.dart';
import '../api/dio_consumer.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_profile_usecase.dart';
import '../../features/profile/domain/usecases/update_profile_usecase.dart';
import '../../features/profile/domain/usecases/change_password_usecase.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/data/datasources/address_remote_data_source.dart';
import '../../features/profile/data/repositories/address_repository_impl.dart';
import '../../features/profile/domain/repositories/address_repository.dart';
import '../../features/profile/domain/usecases/get_addresses_usecase.dart';
import '../../features/profile/domain/usecases/add_address_usecase.dart';
import '../../features/profile/domain/usecases/update_address_usecase.dart';
import '../../features/profile/domain/usecases/delete_address_usecase.dart';
import '../../features/profile/presentation/bloc/address_cubit.dart';
import '../../features/profile/data/datasources/review_remote_data_source.dart';
import '../../features/profile/data/repositories/review_repository_impl.dart';
import '../../features/profile/domain/repositories/review_repository.dart';
import '../../features/profile/domain/usecases/get_my_reviews_usecase.dart';
import '../../features/profile/domain/usecases/get_given_reviews_usecase.dart';
import '../../features/profile/domain/usecases/create_review_usecase.dart';
import '../../features/profile/presentation/bloc/review_cubit.dart';

// Referral Feature
import '../../features/profile/data/datasources/referral_remote_data_source.dart';
import '../../features/profile/data/repositories/referral_repository_impl.dart';
import '../../features/profile/domain/repositories/referral_repository.dart';
import '../../features/profile/domain/usecases/referral_usecases.dart';
import '../../features/profile/presentation/bloc/referral_cubit.dart';

// Support & Feedback Feature
import '../../features/profile/data/datasources/support_remote_data_source.dart';
import '../../features/profile/data/repositories/support_repository_impl.dart';
import '../../features/profile/domain/repositories/support_repository.dart';
import '../../features/profile/domain/usecases/support_usecases.dart';
import '../../features/profile/presentation/bloc/support_cubit.dart';

// Wallet Feature
import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/get_wallet_usecase.dart';
import '../../features/wallet/domain/usecases/deposit_money_usecase.dart';
import '../../features/wallet/domain/usecases/withdraw_money_usecase.dart';
import '../../features/wallet/presentation/cubit/wallet_cubit.dart';

// Trips Feature
import '../../features/trips/data/datasources/trip_remote_data_source.dart';
import '../../features/trips/data/repositories/trip_repository_impl.dart';
import '../../features/trips/domain/repositories/trip_repository.dart';
import '../../features/trips/domain/usecases/get_trips_usecase.dart';
import '../../features/trips/domain/usecases/trip_usecases.dart';
import '../../features/trips/presentation/manager/trip_cubit.dart';

// Notifications Feature
import '../../features/home/data/datasources/notification_remote_data_source.dart';
import '../../features/home/data/repositories/notification_repository_impl.dart';
import '../../features/home/domain/repositories/notification_repository.dart';
import '../../features/home/domain/usecases/notification_usecases.dart';
import '../../features/home/presentation/manager/notification_cubit.dart';
import '../services/appsflyer_service.dart';

final sl = GetIt.instance;

/// Initialize Dependency Injection
Future<void> init() async {
  //! Core
  sl.registerLazySingleton<AppsFlyerService>(() => AppsFlyerServiceImpl());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton<ApiConsumer>(() => DioConsumer(dio: sl()));
  sl.registerLazySingleton<LocationService>(() => LocationService());
  sl.registerLazySingleton(() => NotificationService(sl()));

  //! External
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());

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
    if (kDebugMode && AppConfig.enableLogging) {
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

  //! Shipment Feature
  sl.registerLazySingleton<ShipmentRemoteDataSource>(
    () => ShipmentRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ShipmentRepository>(
    () => ShipmentRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetShipmentsUseCase(sl()));
  sl.registerLazySingleton(() => AddShipmentUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShipmentStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetShipmentByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => UpdateFcmTokenUseCase(sl()));
  sl.registerFactory(
    () => ShipmentCubit(
      getShipmentsUseCase: sl(),
      addShipmentUseCase: sl(),
      updateShipmentStatusUseCase: sl(),
      getShipmentByIdUseCase: sl(),
      shipmentRepository: sl(),
    ),
  );
  sl.registerFactory(
    () => ChatCubit(getMessagesUseCase: sl(), sendMessageUseCase: sl()),
  );

  //! Order Feature
  sl.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetOrdersUseCase(sl()));
  sl.registerLazySingleton(() => CreateOrderUseCase(sl()));
  sl.registerLazySingleton(() => UpdateOrderStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetOrderByIdUseCase(sl()));
  sl.registerFactory(
    () => OrderCubit(
      getOrdersUseCase: sl(),
      createOrderUseCase: sl(),
      updateOrderStatusUseCase: sl(),
      getOrderByIdUseCase: sl(),
      orderRepository: sl(),
    ),
  );

  //! Auth Feature
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(api: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));
  sl.registerLazySingleton(() => ResendOtpUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => UploadDriverDocumentsUseCase(sl()));
  sl.registerFactory(
    () => AuthCubit(
      registerUseCase: sl(),
      verifyOtpUseCase: sl(),
      resendOtpUseCase: sl(),
      loginUseCase: sl(),
      uploadDriverDocumentsUseCase: sl(),
      notificationService: sl(),
    ),
  );

  //! Profile Feature
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
  sl.registerFactory(
    () => ProfileCubit(
      getProfile: sl(),
      updateProfile: sl(),
      changePassword: sl(),
    ),
  );

  // Address Feature
  sl.registerLazySingleton<AddressRemoteDataSource>(
    () => AddressRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<AddressRepository>(
    () => AddressRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetAddressesUseCase(sl()));
  sl.registerLazySingleton(() => AddAddressUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAddressUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAddressUseCase(sl()));
  sl.registerFactory(
    () => AddressCubit(
      getAddresses: sl(),
      addAddress: sl(),
      updateAddress: sl(),
      deleteAddress: sl(),
    ),
  );

  // Review Feature
  sl.registerLazySingleton<ReviewRemoteDataSource>(
    () => ReviewRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetMyReviewsUseCase(sl()));
  sl.registerLazySingleton(() => GetGivenReviewsUseCase(sl()));
  sl.registerLazySingleton(() => CreateReviewUseCase(sl()));
  sl.registerFactory(
    () => ReviewCubit(
      repository: sl(),
      getMyReviews: sl(),
      getGivenReviews: sl(),
      createReview: sl(),
    ),
  );

  // Trips Dependency Registration
  sl.registerLazySingleton<TripRemoteDataSource>(
    () => TripRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<TripRepository>(
    () => TripRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetTripsUseCase(sl()));
  sl.registerLazySingleton(() => AddTripUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTripUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTripUseCase(sl()));
  sl.registerFactory(
    () => TripCubit(
      getTripsUseCase: sl(),
      addTripUseCase: sl(),
      updateTripUseCase: sl(),
      deleteTripUseCase: sl(),
    ),
  );

  // Notifications Dependency Registration
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));
  sl.registerLazySingleton(() => MarkAllNotificationsReadUseCase(sl()));
  sl.registerLazySingleton(() => DeleteNotificationUseCase(sl()));
  sl.registerLazySingleton(() => ClearAllNotificationsUseCase(sl()));
  sl.registerFactory(
    () => NotificationCubit(
      getNotificationsUseCase: sl(),
      markNotificationReadUseCase: sl(),
      markAllNotificationsReadUseCase: sl(),
      deleteNotificationUseCase: sl(),
      clearAllNotificationsUseCase: sl(),
    ),
  );

  // Referral Feature Dependency Registration
  sl.registerLazySingleton<ReferralRemoteDataSource>(
    () => ReferralRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ReferralRepository>(
    () => ReferralRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetReferralSummaryUseCase(sl()));
  sl.registerLazySingleton(() => ConvertPointsUseCase(sl()));
  sl.registerFactory(
    () => ReferralCubit(getReferralSummary: sl(), convertPoints: sl()),
  );

  // Support & Feedback Feature Dependency Registration
  sl.registerLazySingleton<SupportRemoteDataSource>(
    () => SupportRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<SupportRepository>(
    () => SupportRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => SubmitContactMessageUseCase(sl()));
  sl.registerLazySingleton(() => GetSupportMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendSupportMessageUseCase(sl()));
  sl.registerFactory(
    () => SupportCubit(
      submitContactUseCase: sl(),
      getMessagesUseCase: sl(),
      sendMessageUseCase: sl(),
    ),
  );

  // Wallet Feature Dependency Registration
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<WalletRepository>(() => WalletRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetWalletUseCase(sl()));
  sl.registerLazySingleton(() => CreateDepositSessionUseCase(sl()));
  sl.registerLazySingleton(() => CheckDepositSessionUseCase(sl()));
  sl.registerLazySingleton(() => WithdrawMoneyUseCase(sl()));
  sl.registerFactory(
    () => WalletCubit(
      getWalletUseCase: sl(),
      createDepositSessionUseCase: sl(),
      checkDepositSessionUseCase: sl(),
      withdrawMoneyUseCase: sl(),
    ),
  );
}
