// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/notifications/notification_service.dart';
import 'package:we_deliver/core/services/firebase_config_service.dart';
import 'package:we_deliver/core/utils/prefs_helper.dart';

class ApiInterceptor extends Interceptor {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.data is! FormData) {
      options.headers['Content-Type'] = 'application/json';
    }

    // Secure persistent Device ID Generation
    var deviceId = await secureStorage.read(key: 'device_id');
    if (deviceId == null || deviceId.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      deviceId = base64Url.encode(values).replaceAll(RegExp(r'[=-_]'), '');
      await secureStorage.write(key: 'device_id', value: deviceId);
    }
    options.headers['x-device-id'] = deviceId;

    final token =
        await secureStorage.read(key: 'token') ??
        await SecureCacheHelper().getData(key: ApiKey.token);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Generate secure dynamic HMAC-SHA256 signature for request validation
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signingSecret = FirebaseConfigService.apiCryptoStaticKey.isNotEmpty
        ? FirebaseConfigService.apiCryptoStaticKey
        : 'fallback_api_crypto_static_key_we_deliver_2026';
    
    final hmacKey = utf8.encode(signingSecret);
    final hmacEngine = Hmac(sha256, hmacKey);
    final signatureDigest = hmacEngine.convert(utf8.encode(timestamp + deviceId));
    
    options.headers['x-timestamp'] = timestamp;
    options.headers['x-signature'] = signatureDigest.toString();

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 0. Handle Banned Users (403)
    if (err.response?.statusCode == 403 &&
        err.response?.data is Map &&
        err.response?.data['is_banned'] == true) {
      await secureStorage.delete(key: 'token');
      await secureStorage.delete(key: 'refresh_token');
      await SecureCacheHelper().removeData(key: ApiKey.token);
      await PrefsHelper.clearSessionKeepCredentials();
      NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (route) => false,
      );
      return super.onError(err, handler);
    }

    // 1. Handle Device Mismatch Binding Error
    if (err.response?.statusCode == 401 &&
        err.response?.data is Map &&
        err.response?.data['errorCode'] == 'DEVICE_MISMATCH') {
      await secureStorage.delete(key: 'token');
      await secureStorage.delete(key: 'refresh_token');
      await SecureCacheHelper().removeData(key: ApiKey.token);
      await PrefsHelper.clearSessionKeepCredentials();
      NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (route) => false,
      );
      return super.onError(err, handler);
    }

    // Handle Token Expiry
    if (err.response?.statusCode == 401) {
      final message = err.response?.data is Map
          ? err.response?.data['message']
          : null;

      if (message == 'Refresh TokenExpiredError' ||
          message == 'التوكن غير صالح أو منتهي الصلاحية') {
        // Even the refresh token is dead, force logout
        await secureStorage.delete(key: 'token');
        await secureStorage.delete(key: 'refresh_token');
        await SecureCacheHelper().removeData(key: ApiKey.token);
        await PrefsHelper.clearSessionKeepCredentials();
        NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          Routes.login,
          (route) => false,
        );
        return super.onError(err, handler);
      }

      // Check if it's an Access Token Expiry and we have a refresh token
      final refreshToken = await secureStorage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          // Attempt to refresh
          final dio = Dio();
          dio.options.baseUrl = EndPoint.baseUrl;
          final currentDeviceId = await secureStorage.read(key: 'device_id');
          
          // Compute secure HMAC signature for the refresh request
          final refreshTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final signingSecret = FirebaseConfigService.apiCryptoStaticKey.isNotEmpty
              ? FirebaseConfigService.apiCryptoStaticKey
              : 'fallback_api_crypto_static_key_we_deliver_2026';
          
          final hmacKey = utf8.encode(signingSecret);
          final hmacEngine = Hmac(sha256, hmacKey);
          final refreshDigest = hmacEngine.convert(utf8.encode(refreshTimestamp + (currentDeviceId ?? '')));
          
          if (currentDeviceId != null) {
            dio.options.headers['x-device-id'] = currentDeviceId;
          }
          dio.options.headers['x-timestamp'] = refreshTimestamp;
          dio.options.headers['x-signature'] = refreshDigest.toString();

          final response = await dio.post(
            EndPoint.refreshToken,
            data: {'refresh_token': refreshToken},
          );

          final newAccessToken = response.data['token'];
          final newRefreshToken = response.data['refresh_token'];
          
          await secureStorage.write(key: 'token', value: newAccessToken);
          if (newRefreshToken != null) {
            await secureStorage.write(key: 'refresh_token', value: newRefreshToken);
          }

          // Retry original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';
          if (currentDeviceId != null) {
            opts.headers['x-device-id'] = currentDeviceId;
            
            // Recalculate signature for the retried request to avoid timestamp expiration/replay detection
            final retryTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
            final retryDigest = hmacEngine.convert(utf8.encode(retryTimestamp + currentDeviceId));
            
            opts.headers['x-timestamp'] = retryTimestamp;
            opts.headers['x-signature'] = retryDigest.toString();
          }
          final retryResponse = await dio.fetch(opts);
          return handler.resolve(retryResponse);
        } catch (e) {
          // Refresh failed
          await secureStorage.delete(key: 'token');
          await secureStorage.delete(key: 'refresh_token');
          await SecureCacheHelper().removeData(key: ApiKey.token);
          await PrefsHelper.clearSessionKeepCredentials();
          NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            Routes.login,
            (route) => false,
          );
        }
      } else {
        await secureStorage.delete(key: 'token');
        await SecureCacheHelper().removeData(key: ApiKey.token);
        await PrefsHelper.clearSessionKeepCredentials();
        NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          Routes.login,
          (route) => false,
        );
      }
    }

    super.onError(err, handler);
  }
}
