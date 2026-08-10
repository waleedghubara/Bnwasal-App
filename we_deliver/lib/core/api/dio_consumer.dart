import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:we_deliver/core/api/api_consumer.dart';
import 'package:we_deliver/core/api/api_interceptors.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/errors/exception.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/config/security_config.dart';

class DioConsumer extends ApiConsumer {
  DioConsumer({required this.dio}) {
    dio.options.baseUrl = EndPoint.baseUrl;
    dio.interceptors.add(ApiInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          // Detect Handshake / Certificate errors and wrap them in a generic secure message
          final isSslFailure =
              e.error is HandshakeException ||
              e.message?.contains('HandshakeException') == true ||
              e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true ||
              e.type == DioExceptionType.badCertificate;

          if (isSslFailure) {
            final secureError = DioException(
              requestOptions: e.requestOptions,
              type: DioExceptionType.connectionError,
              error: const TlsException(
                'Secure connection verification failed',
              ),
              message:
                  'فشل الاتصال الآمن بالخادم. يرجى التحقق من الاتصال بالشبكة.',
            );
            return handler.next(secureError);
          }

          if (e.response?.statusCode == 500 ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            // AppRouter.navigatorKey.currentState?.pushNamed(Routes.serverError);
          }
          return handler.next(e);
        },
      ),
    );
    _configureSslPinning();
  }
  final Dio dio;

  void _configureSslPinning() {
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              // Check for debug/development environment bypasses
              if (SecurityConfig.shouldBypassPinning(host)) {
                SecurityConfig.logSecurityEvent(
                  'Bypassing SSL Pinning for development host: $host',
                );
                return true;
              }

              final fingerprint = sha256
                  .convert(cert.der)
                  .toString()
                  .toLowerCase();

              SecurityConfig.logSecurityEvent(
                'Verifying Server Certificate Fingerprint: $fingerprint',
              );

              final pins = SecurityConfig.allowedFingerprints;
              for (final pin in pins) {
                if (SecurityConfig.safeEquals(pin, fingerprint)) {
                  SecurityConfig.logSecurityEvent(
                    'SSL Pinning Verified for host: $host',
                  );
                  return true; // Match found - connection is trusted
                }
              }

              SecurityConfig.logSecurityEvent(
                'Security Alert: Certificate fingerprint mismatch for host $host!',
              );
              return false; // Rejects the connection to prevent MITM
            };
        return client;
      };
    }
  }

  @override
  Future delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFromData = false,
  }) async {
    try {
      final response = await dio.delete(
        path,
        data: (data is FormData)
            ? data
            : (isFromData ? FormData.fromMap(data) : data),
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      handleDioExceptions(e);
    }
  }

  @override
  Future get(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      handleDioExceptions(e);
    }
  }

  @override
  Future put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFromData = false,
  }) async {
    try {
      final response = await dio.put(
        path,
        data: (data is FormData)
            ? data
            : (isFromData ? FormData.fromMap(data) : data),
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      handleDioExceptions(e);
    }
  }

  @override
  Future post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFromData = false,
  }) async {
    try {
      final response = await dio.post(
        path,
        data: (data is FormData)
            ? data
            : (isFromData ? FormData.fromMap(data) : data),
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {}
      handleDioExceptions(e);
    }
  }

  @override
  Future patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFromData = false,
  }) async {
    try {
      final response = await dio.patch(
        path,
        data: (data is FormData)
            ? data
            : (isFromData ? FormData.fromMap(data) : data),
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      handleDioExceptions(e);
    }
  }
}
