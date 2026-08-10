import 'dart:convert';
import 'dart:math';
import 'package:admin_bnwasal/core/routes/routes.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Global navigator key so the interceptor can navigate even without
/// a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Must match API_CRYPTO_STATIC_KEY in the backend .env / Firebase Remote Config
const String _signingSecret = 'fallback_api_crypto_static_key_we_deliver_2026';

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

    String? token;
    try {
      token = await secureStorage.read(key: 'token');
    } catch (e) {
      debugPrint('Error reading secure storage token: $e');
    }

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // --- Secure HMAC-SHA256 signature headers ---
    // Generate or reuse a persistent device ID
    String? deviceId;
    try {
      deviceId = await secureStorage.read(key: 'device_id');
      if (deviceId == null || deviceId.isEmpty) {
        final random = Random.secure();
        final values = List<int>.generate(16, (i) => random.nextInt(256));
        deviceId = base64Url.encode(values).replaceAll(RegExp(r'[=\-_]'), '');
        try {
          await secureStorage.write(key: 'device_id', value: deviceId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error accessing device_id in secure storage: $e');
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      deviceId = base64Url.encode(values).replaceAll(RegExp(r'[=\-_]'), '');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final hmacKey = utf8.encode(_signingSecret);
    final signature =
        Hmac(sha256, hmacKey).convert(utf8.encode(timestamp + deviceId!));

    options.headers['x-device-id'] = deviceId;
    options.headers['x-timestamp'] = timestamp;
    options.headers['x-signature'] = signature.toString();
    // -------------------------------------------

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await secureStorage.delete(key: 'token');
      } catch (e) {
        debugPrint('Error deleting token: $e');
      }
      await secureStorage.delete(key: 'refresh_token');

      // Redirect to login screen
      appNavigatorKey.currentState
          ?.pushNamedAndRemoveUntil(Routes.login, (_) => false);

      return super.onError(err, handler);
    }

    super.onError(err, handler);
  }
}
