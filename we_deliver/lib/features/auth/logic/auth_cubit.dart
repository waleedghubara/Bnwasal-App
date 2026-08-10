import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/errors/failure.dart';
import '../domain/usecases/auth_usecases.dart';
import 'auth_state.dart';
import '../../../../core/notifications/notification_service.dart';

class AuthCubit extends Cubit<AuthState> {
  final RegisterUseCase registerUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final ResendOtpUseCase resendOtpUseCase;
  final LoginUseCase loginUseCase;
  final UploadDriverDocumentsUseCase uploadDriverDocumentsUseCase;
  final NotificationService notificationService;

  AuthCubit({
    required this.registerUseCase,
    required this.verifyOtpUseCase,
    required this.resendOtpUseCase,
    required this.loginUseCase,
    required this.uploadDriverDocumentsUseCase,
    required this.notificationService,
  }) : super(AuthInitial());

  Future<void> register({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    required String password,
    required String role,
    File? profileImage,
    String? referralCode,
  }) async {
    emit(AuthLoading());
    final result = await registerUseCase(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      role: role,
      profileImage: profileImage,
      referralCode: referralCode,
    );

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (responseMap) {
        final data = responseMap['data'] as Map<String, dynamic>;
        final otp = data['otpCode']?.toString() ?? '';
        emit(RegisterSuccess(
          email: email ?? phone,
          otpCode: otp,
          message: responseMap['message'] as String,
        ));
      },
    );
  }

  Future<void> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    emit(AuthLoading());
    final result = await verifyOtpUseCase(
      phone: phone,
      otpCode: otpCode,
    );

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (authResponse) async {
        await _saveAuthSession(
          id: authResponse.user.id,
          token: authResponse.token,
          refreshToken: authResponse.refreshToken,
          role: authResponse.user.role,
        );
        emit(VerifyOtpSuccess(authResponse: authResponse));
      },
    );
  }

  Future<void> resendOtp({
    required String phone,
  }) async {
    emit(AuthLoading());
    final result = await resendOtpUseCase(phone: phone);

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (message) => emit(ResendOtpSuccess(message: message, newOtp: '')),
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    final result = await loginUseCase(
      email: email,
      password: password,
    );

    result.fold(
      (failure) {
        // Check if account is pending admin approval
        if (failure is ServerFailure &&
            failure.errorCode == 'PENDING_APPROVAL') {
          emit(LoginPendingApproval(message: failure.message));
        } else if (failure is ServerFailure &&
            failure.errorCode == 'PENDING_OTP') {
          emit(LoginPendingOtp(
            email: email,
            otpCode: '',
            message: failure.message,
          ));
        } else {
          emit(AuthError(message: failure.message));
        }
      },
      (authResponse) async {
        await _saveAuthSession(
          id: authResponse.user.id,
          token: authResponse.token,
          refreshToken: authResponse.refreshToken,
          role: authResponse.user.role,
        );
        emit(LoginSuccess(authResponse: authResponse));
      },
    );
  }

  Future<void> uploadDriverDocuments({
    required String nationalId,
    required File nationalIdFront,
    required File nationalIdBack,
  }) async {
    emit(AuthLoading());
    final result = await uploadDriverDocumentsUseCase(
      nationalId: nationalId,
      nationalIdFront: nationalIdFront,
      nationalIdBack: nationalIdBack,
    );

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (message) => emit(UploadDocsSuccess(message: message)),
    );
  }

  Future<void> _saveAuthSession({
    required int id,
    required String token,
    required String refreshToken,
    required String role,
  }) async {
    final cacheHelper = SecureCacheHelper();
    await cacheHelper.saveData(key: ApiKey.id, value: id.toString());
    await cacheHelper.saveData(key: ApiKey.token, value: token);
    await cacheHelper.saveData(key: 'refresh_token', value: refreshToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isDelivery', role == 'captain');

    // Sync FCM token to backend
    await notificationService.syncToken();
  }

  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
