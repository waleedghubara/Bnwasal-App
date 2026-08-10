import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:admin_bnwasal/core/services/notification_service.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import '../../../../core/api/dio_consumer.dart';
import '../../data/auth_api.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthApi _authApi;
  final FlutterSecureStorage _storage;

  AuthCubit(this._authApi, this._storage) : super(const AuthState());

  Future<void> login(String email, String password) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final response = await _authApi.login(email, password);
      final data = response['data'] as Map<String, dynamic>;

      final token = data['token'] as String;
      final refreshToken = data['refresh_token'] as String?;
      final user = data['user'] as Map<String, dynamic>;

      await _storage.write(key: 'token', value: token);
      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }
      await _storage.write(key: 'user', value: jsonEncode(user));

      emit(
        state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: token,
          user: user,
        ),
      );

      // Register socket userId and send FCM token
      NotificationService().setSocketUserId(user['id'].toString());
      NotificationService().connectSocket();
      _sendFcmToken(token);
    } catch (e) {
      String message = 'حدث خطأ في تسجيل الدخول';
      if (e.toString().contains('بيانات الدخول غير صحيحة')) {
        message = 'بيانات الدخول غير صحيحة';
      } else if (e.toString().contains('محظور')) {
        message = 'هذا الحساب محظور';
      }
      emit(state.copyWith(isLoading: false, errorMessage: message));
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _authApi.logout(refreshToken);
      }
    } catch (_) {}

    await _storage.deleteAll();
    NotificationService().disconnectSocket();
    emit(const AuthState());
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'token');
    if (token != null && token.isNotEmpty) {
      final userStr = await _storage.read(key: 'user');
      Map<String, dynamic>? user;
      if (userStr != null) {
        try {
          user = jsonDecode(userStr) as Map<String, dynamic>;
        } catch (_) {}
      }
      emit(state.copyWith(isAuthenticated: true, token: token, user: user));
      if (user != null && user['id'] != null) {
        NotificationService().setSocketUserId(user['id'].toString());
        NotificationService().connectSocket();
      }
    }
  }

  Future<void> loadProfile() async {
    emit(state.copyWith(isLoadingProfile: true));
    try {
      final response = await _authApi.getProfile();
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _storage.write(key: 'user', value: jsonEncode(user));
      emit(state.copyWith(isLoadingProfile: false, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProfile: false,
          errorMessage: 'فشل تحميل الملف الشخصي',
        ),
      );
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
  }) async {
    emit(state.copyWith(isLoadingProfile: true, profileSuccess: null));
    try {
      final response = await _authApi.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        city: city,
      );
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _storage.write(key: 'user', value: jsonEncode(user));
      emit(
        state.copyWith(
          isLoadingProfile: false,
          user: user,
          profileSuccess: 'تم تحديث البيانات بنجاح',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProfile: false,
          errorMessage: 'فشل تحديث البيانات',
        ),
      );
    }
  }

  Future<void> updateProfileImage(String filePath) async {
    emit(state.copyWith(isLoadingProfile: true, profileSuccess: null));
    try {
      final response = await _authApi.updateProfileImage(filePath);
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _storage.write(key: 'user', value: jsonEncode(user));
      emit(
        state.copyWith(
          isLoadingProfile: false,
          user: user,
          profileSuccess: 'تم تحديث الصورة بنجاح',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProfile: false,
          errorMessage: 'فشل تحديث الصورة',
        ),
      );
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    emit(state.copyWith(isLoadingProfile: true, profileSuccess: null));
    try {
      await _authApi.changePassword(oldPassword, newPassword);
      emit(
        state.copyWith(
          isLoadingProfile: false,
          profileSuccess: 'تم تغيير كلمة المرور بنجاح',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProfile: false,
          errorMessage: 'فشل تغيير كلمة المرور',
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(errorMessage: null, profileSuccess: null));
  }

  Future<void> _sendFcmToken(String authToken) async {
    final fcmToken = NotificationService().fcmToken;
    if (fcmToken == null) return;
    try {
      final dio = di.sl<DioConsumer>();
      await dio.put(EndPoint.updateFcmToken, data: {'fcmToken': fcmToken});
    } catch (_) {}
  }
}
