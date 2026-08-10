import 'package:we_deliver/core/services/firebase_config_service.dart';
import 'dart:convert';

class EndPoint {
  /// تفعيل وضع التطوير لتجاوز فحوصات الأمان (RASP) مؤقتاً أثناء البرمجة والاختبار.
  /// [true] = تجاوز الفحوصات بالكامل، [false] = تطبيق الحماية بالاعتماد على الفحوصات الفردية بالأسفل.
  static const bool bypassSecurity = true;

  // خيارات التحكم في فحوصات الأمان الفردية أثناء التطوير (قم بتغييرها إلى false لتعطيل الفحص)
  static const bool checkDebugMode = true; // التحقق من وضع التطوير (kDebugMode)
  static const bool checkUsbDebugging =
      true; // التحقق من تصحيح أخطاء USB (USB Debugging)
  static const bool checkEmulator =
      true; // التحقق من تشغيل التطبيق على محاكي (Emulator)
  static const bool checkRoot = true; // التحقق من وجود صلاحيات الروت (Root)
  static const bool checkFrida =
      true; // التحقق من أدوات التلاعب بالذاكرة (Frida)
  static const bool checkDebugger =
      true; // التحقق من اتصال مصحح الأخطاء (Debugger)
  static const bool checkNativeDebug =
      true; // التحقق من وضع debuggable على نظام أندرويد
  static const bool checkSignature = true; // التحقق من توقيع التطبيق
  static const bool checkIntegrity =
      true; // التحقق من سلامة التطبيق وحزم الاستنساخ

  // Static Constants Decrypted at Runtime
  static final String markRead = ApiCrypto.decrypt(
    'e4OVs6-5op_LvcLo5DcA1-_vKhYyITv8LTBR',
  ); // Original: notifications/mark_read.php
  static final String baseUrl = ApiCrypto.decrypt(
    'gY6VqqTs5m3Zusrr5O0BpADz-GE2Ejj9',
  ); // Original: https://bnwasal.com/api/
  static final String appConfig = ApiCrypto.decrypt(
    'mH2Vpr7AnrEUx8Lo2fX2',
  ); // Original: settings/config
  static final String imageBaseUrl = ApiCrypto.decrypt(
    'gY6VqqTs5m3Zusrr5O0BpADz-A==',
  ); // Original: https://bnwasal.com

  // Auth Endpoints
  static final String register = ApiCrypto.decrypt(
    'io2Vsvi0oKXO183v5Q==',
  ); // Original: auth/register
  static final String login = ApiCrypto.decrypt(
    'io2Vsvi-pqXOug==',
  ); // Original: auth/login
  static final String verifyOtp = ApiCrypto.decrypt(
    'io2Vsvi4oLLOwtgn0OLl',
  ); // Original: auth/verify-otp
  static final String resendOtp = ApiCrypto.decrypt(
    'io2Vsvi0oLHaur0n0OLl',
  ); // Original: auth/resend-otp
  static final String getProfile = ApiCrypto.decrypt(
    'io2Vsviysa3dvcXv',
  ); // Original: auth/profile
  static final String updateProfile = ApiCrypto.decrypt(
    'io2Vsviysa3dvcXv',
  ); // Original: auth/profile
  static final String changePassword = ApiCrypto.decrypt(
    'io2VsvjDq5_Vw7wn4-3i6fTzDyg=',
  ); // Original: auth/change-password
  static final String refreshToken = ApiCrypto.decrypt(
    'io2Vsvi0oKbJwc7iDuL-4QL0',
  ); // Original: auth/refresh-token
  static final String logout = ApiCrypto.decrypt(
    'io2Vsvi-pqXU0c0=',
  ); // Original: auth/logout
  static final String uploadDriverDocuments = ApiCrypto.decrypt(
    'io2VsvjGsafNwc8p5t4B5f76OCgoIyw_OipNPQ==',
  ); // Original: auth/driver/upload-documents
  static final String forgotPassword = ApiCrypto.decrypt(
    'io2VsvjIprLcu80n4-3i6fTzDyg=',
  ); // Original: auth/forgot-password
  static final String verifyResetOtp = ApiCrypto.decrypt(
    'io2Vsvi4oLLOwtgn5fHi2_Gx-hgl',
  ); // Original: auth/verify-reset-otp
  static final String resetPassword = ApiCrypto.decrypt(
    'io2Vsvi0oLHa0ITa0tvi7QwIAQ==',
  ); // Original: auth/reset-password

  // Shipment Endpoints
  static final String createShipment = ApiCrypto.decrypt(
    'mIqwqrrFpbTI',
  ); // Original: shipments
  static final String getShipments = ApiCrypto.decrypt(
    'mIqwqrrFpbTI',
  ); // Original: shipments

  // Order Endpoints
  static final String createOrder = ApiCrypto.decrypt(
    'fJClt6Oz',
  ); // Original: orders
  static final String getOrders = ApiCrypto.decrypt(
    'fJClt6Oz',
  ); // Original: orders

  // Segment references for building dynamic URLs
  static final String _segmentOrdersSlash = ApiCrypto.decrypt(
    'fJClt6Oz5g==',
  ); // Original: orders/
  static final String _segmentSlashStatus = ApiCrypto.decrypt(
    'PI-Vu6G1sg==',
  ); // Original: /status
  static final String _segmentNotificationsSlash = ApiCrypto.decrypt(
    'e4OVs6-5op_LvcLo5Dc=',
  ); // Original: notifications/
  static final String _segmentSlashRead = ApiCrypto.decrypt(
    'PJCku7E=',
  ); // Original: /read
  static final String _segmentTripsSlash = ApiCrypto.decrypt(
    'lZCwqqT_',
  ); // Original: trips/
  static final String _segmentShipmentsSlash = ApiCrypto.decrypt(
    'mIqwqrrFpbTI-w==',
  ); // Original: shipments/
  static final String _segmentSlashMessages = ApiCrypto.decrypt(
    'PIWkraTBnqPI',
  ); // Original: /messages
  static final String _segmentSlashConfirmPickup = ApiCrypto.decrypt(
    'PH-qsK-5sasS1MjtzOHl',
  ); // Original: /confirm-pickup
  static final String _segmentSlashConfirmDelivery = ApiCrypto.decrypt(
    'PH-qsK-5sasSwLzmyuD46PY=',
  ); // Original: /confirm-delivery

  // Dynamic Methods Decrypted at Runtime
  static String updateOrderStatus(String orderId) =>
      _segmentOrdersSlash + orderId + _segmentSlashStatus;
  static String getOrderById(String orderId) => _segmentOrdersSlash + orderId;

  // Notifications Endpoints
  static final String getNotifications = ApiCrypto.decrypt(
    'e4OVs6-5op_LvcLo5A==',
  ); // Original: notifications
  static String markNotificationRead(String id) =>
      _segmentNotificationsSlash + id + _segmentSlashRead;
  static final String markAllNotificationsRead = ApiCrypto.decrypt(
    'e4OVs6-5op_LvcLo5Dfj2_76OCMpLg==',
  ); // Original: notifications/read-all
  static String deleteNotification(String id) =>
      _segmentNotificationsSlash + id;
  static final String clearAllNotifications = ApiCrypto.decrypt(
    'e4OVs6-5op_LvcLo5Dfy4gL1D182LjM=',
  ); // Original: notifications/clear-all

  // Trips Endpoints
  static final String getTrips = ApiCrypto.decrypt(
    'lZCwqqQ=',
  ); // Original: trips
  static final String createTrip = ApiCrypto.decrypt(
    'lZCwqqQ=',
  ); // Original: trips
  static String updateTrip(String id) => _segmentTripsSlash + id;
  static String deleteTrip(String id) => _segmentTripsSlash + id;

  // Referral Endpoints
  static final String referralSummary = ApiCrypto.decrypt(
    'l32jt6O0pKzI-87fzvn06PY=',
  ); // Original: referrals/summary
  static final String convertPoints = ApiCrypto.decrypt(
    'l32jt6O0pKzI-77p0eD46PGxDSEuMCs5',
  ); // Original: referrals/convert-points

  // Support Endpoints
  static final String contactUs = ApiCrypto.decrypt(
    'mI2Zqri0r23Yu8Pe0uvp',
  ); // Original: support/contact
  static final String supportChat = ApiCrypto.decrypt(
    'mI2Zqri0r23YvMDe',
  ); // Original: support/chat

  static final String socketUrl = ApiCrypto.decrypt(
    'gY6VqqTs5m3Zusrr5O0BpADz-A==',
  ); // Original: https://bnwasal.com
  static final String updateFcmToken = ApiCrypto.decrypt(
    'io2VsvjIoqsS0MLl1vg=',
  ); // Original: auth/fcm-token
  static String shipmentMessages(String shipmentId) =>
      _segmentShipmentsSlash + shipmentId + _segmentSlashMessages;

  // Negotiation & Payments Endpoints
  static final String submitOffer = ApiCrypto.decrypt(
    'e32isaG5pLTOu8Mp0PD32-8=',
  ); // Original: negotiation/offer
  static final String acceptOffer = ApiCrypto.decrypt(
    'e32isaG5pLTOu8Mp0uvy2-0K',
  ); // Original: negotiation/accept
  static final String rejectOffer = ApiCrypto.decrypt(
    'e32isaG5pLTOu8Mp5fH72wAK',
  ); // Original: negotiation/reject
  static final String getOffers = ApiCrypto.decrypt(
    'e32isaG5pLTOu8Mp0PD32-8H',
  ); // Original: negotiation/offers
  static final String submitCounterOffer = ApiCrypto.decrypt(
    'e32isaG5pLTOu8Mp0PD32-8K',
  ); // Original: negotiation/counter-offer
  static final String payDelivery = ApiCrypto.decrypt(
    'mYGgr7LAr7EU1MDTDvL44gYMABYe',
  ); // Original: payments/pay-delivery

  // Direct Payment Endpoints (pay-now with receipt upload)
  static final String directPaymentMethods = 'direct-payments/methods';
  static final String directPaymentSubmit = 'direct-payments/submit';
  static String directPaymentStatus(String ref) =>
      'direct-payments/status/$ref';

  static String confirmShipmentPickup(String id) =>
      _segmentShipmentsSlash + id + _segmentSlashConfirmPickup;
  static String confirmShipmentDelivery(String id) =>
      _segmentShipmentsSlash + id + _segmentSlashConfirmDelivery;
  static String confirmOrderPickup(String id) =>
      _segmentOrdersSlash + id + _segmentSlashConfirmPickup;
  static String confirmOrderDelivery(String id) =>
      _segmentOrdersSlash + id + _segmentSlashConfirmDelivery;

  // Wallet Endpoints
  static final String getWalletData = ApiCrypto.decrypt(
    'lIGtrrK25qTW0MA=',
  ); // Original: wallet/data
  static final String getTransactions = ApiCrypto.decrypt(
    'lIGtrrK25rTJxcPd0uvp3wz0Dg==',
  ); // Original: wallet/transactions
  static final String createDepositSession = ApiCrypto.decrypt(
    'lIGtrrK25qHJwcDe1jn52-3zDhshbTJHMEdYOV8=',
  ); // Original: wallet/create-deposit-session
  static final String checkDepositSession = ApiCrypto.decrypt(
    'lIGtrrK25qHPwb7lDtv46fDt-iI=',
  ); // Original: wallet/check-session
  static final String withdraw = ApiCrypto.decrypt(
    'lIGtrrK25rXO0Mnu5e3m',
  ); // Original: wallet/withdraw
}

class ApiKey {
  static String id = 'id';
  static String token = 'token';
  static String message = 'message';
  static String status = 'status';
  static String errormessage = 'ErrorMessage';
  static String name = 'name';
  static String storeName = 'storeName';
  static String tradeType = 'tradeType';
  static String city = 'city';
  static String address = 'address';
  static String email = 'email';
  static String password = 'password';
  static String confirmPassword = 'confirmPassword';
  static String phone = 'phone';
  static String profileImage = 'profileImage';
  static String imageDocument = 'imageDocument';
  static String verifyotpphone = 'verifyotpphone';
  static String verifyotpemail = 'otp_code';
  static String oldPassword = 'Old_password';
  static String newPassword = 'New_password';
  static String count = 'count';
  static String nameAddFayah = 'nameaddFayah';
  static String vehicle = 'vehicle';
  static String plate = 'plate';
}

/// A secure 4-stage reversible encryption cipher (XOR + Substitution + Index Shift + Base64)
class ApiCrypto {
  ApiCrypto._();

  static String get _staticKey {
    final key = FirebaseConfigService.apiCryptoStaticKey;
    return key.isNotEmpty ? key : "";
  }

  /// Stage 1: Deterministic key-stream generation using a seeded linear congruential generator (LCG)
  static List<int> _generateKeyStream(int length) {
    final key = _staticKey;
    int seed = 0;
    for (int i = 0; i < key.length; i++) {
      seed = (seed * 31 + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }

    final stream = List<int>.filled(length, 0);
    int state = seed;
    for (int i = 0; i < length; i++) {
      state = (state * 1103515245 + 12345) & 0xFFFFFFFF;
      stream[i] = (state >> 16) & 0xFF;
    }
    return stream;
  }

  /// Stage 2: Reversible bitwise XOR operation
  static List<int> _stageXor(List<int> bytes) {
    final keyStream = _generateKeyStream(bytes.length);
    final result = List<int>.filled(bytes.length, 0);
    for (int i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyStream[i];
    }
    return result;
  }

  /// Stage 3: Reversible custom Byte Substitution (Caesar shift using key-stream offset)
  static List<int> _stageSubstitute(List<int> bytes, bool encrypt) {
    final keyStream = _generateKeyStream(bytes.length);
    final result = List<int>.filled(bytes.length, 0);
    for (int i = 0; i < bytes.length; i++) {
      final shift = keyStream[i] % 256;
      if (encrypt) {
        result[i] = (bytes[i] + shift) % 256;
      } else {
        result[i] = (bytes[i] - shift + 256) % 256;
      }
    }
    return result;
  }

  /// Stage 4: Reversible position-based Byte Shift (Vigenere shift using index offset)
  static List<int> _stageIndexShift(List<int> bytes, bool encrypt) {
    final result = List<int>.filled(bytes.length, 0);
    for (int i = 0; i < bytes.length; i++) {
      final shift = (i * 7 + 13) % 256;
      if (encrypt) {
        result[i] = (bytes[i] + shift) % 256;
      } else {
        result[i] = (bytes[i] - shift + 256) % 256;
      }
    }
    return result;
  }

  /// Helper to encrypt strings (for reference / development)
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    final bytes = utf8.encode(plainText);

    final xorBytes = _stageXor(bytes);
    final subBytes = _stageSubstitute(xorBytes, true);
    final shiftBytes = _stageIndexShift(subBytes, true);
    return base64Url.encode(shiftBytes);
  }

  /// Helper to decrypt strings (used at runtime)
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    try {
      final bytes = base64Url.decode(encryptedText);
      final unshiftedBytes = _stageIndexShift(bytes, false);
      final unsubstitutedBytes = _stageSubstitute(unshiftedBytes, false);
      final decryptedBytes = _stageXor(unsubstitutedBytes);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return "DECRYPTION_ERROR: $e";
    }
  }
}
