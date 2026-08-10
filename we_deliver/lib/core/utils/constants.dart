import 'dart:convert';
import 'package:we_deliver/core/services/firebase_config_service.dart';

/// Application Constants
/// Centralized constant definitions
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // Secure Google Maps API Key (Obfuscated using a custom 4-stage encryption pipeline to prevent automated detection or manual reverse-engineering)
  static String get googleMapsApiKey {
    final obfuscated = FirebaseConfigService.googleMapsApiKey;
    if (obfuscated.isEmpty || obfuscated.length < 6) {
      return '';
    }
    
    // Stage 4: Strip dynamic salt and reverse base64 string
    final cleanB64 = obfuscated.substring(3, obfuscated.length - 3);
    final reversedB64 = cleanB64.split('').reversed.join('');
    
    // Base64 decoding
    final decodedBytes = base64.decode(reversedB64);
    final n = decodedBytes.length;
    final List<int> mutableBytes = List.from(decodedBytes);
    
    // Stage 3: Reverse adjacent byte swapping and reverse array order
    for (int i = 0; i < n - 1; i += 2) {
      final temp = mutableBytes[i];
      mutableBytes[i] = mutableBytes[i + 1];
      mutableBytes[i + 1] = temp;
    }
    final reversedBytes = List<int>.from(mutableBytes.reversed);
    
    // Stage 2: Rotating key XOR decryption
    final passphrase = FirebaseConfigService.securityXorPassphrase;
    if (passphrase.isEmpty) {
      return '';
    }
    final passBytes = utf8.encode(passphrase);
    for (int i = 0; i < n; i++) {
      reversedBytes[i] = reversedBytes[i] ^ passBytes[i % passBytes.length];
    }
    
    // Stage 1: Mathematical byte shift reversal
    final List<int> originalBytes = List.filled(n, 0);
    for (int i = 0; i < n; i++) {
      originalBytes[i] = (reversedBytes[i] - (i * 7 + 13)) % 256;
    }
    
    return utf8.decode(originalBytes);
  }

  // API Configuration
  static const String baseUrl = 'https://benwasal.com';
  static const String apiVersion = 'v1';
  static const Duration connectionTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String onboardingKey = 'onboarding_completed';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;

  // Border Radius
  static const double radiusSM = 4.0;
  static const double radiusMD = 8.0;
  static const double radiusLG = 12.0;
  static const double radiusXL = 16.0;
  static const double radiusRound = 999.0;

  // Icon Sizes
  static const double iconSizeSM = 16.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;
  static const double iconSizeXL = 48.0;

  // Image Sizes
  static const double avatarSizeSM = 32.0;
  static const double avatarSizeMD = 48.0;
  static const double avatarSizeLG = 64.0;
  static const double avatarSizeXL = 96.0;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;

  // File Upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
  ];
  static const List<String> allowedDocumentExtensions = ['pdf', 'doc', 'docx'];

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Regular Expressions
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
  static final RegExp urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  // Error Messages
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'No internet connection. Please check your network.';
  static const String timeoutErrorMessage =
      'Request timeout. Please try again.';
  static const String unauthorizedErrorMessage =
      'Unauthorized. Please login again.';
}
