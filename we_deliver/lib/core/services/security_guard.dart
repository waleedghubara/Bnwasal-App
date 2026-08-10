// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:we_deliver/core/api/end_point.dart';

enum SecurityStatus { secure, blocked }

class SecurityGuard {
  static const MethodChannel _channel = MethodChannel(
    'com.example.we_deliver/security',
  );

  static String? _blockReason;
  static String? get blockReason => _blockReason;

  static String? _solutionSteps;
  static String? get solutionSteps => _solutionSteps;

  static Future<SecurityStatus> checkSecurity() async {
    // 0. If bypassSecurity is enabled in EndPoint, skip all checks
    if (EndPoint.bypassSecurity) {
      // debugPrint('🛡️ Security Guard: Bypassed all security checks via EndPoint.bypassSecurity');
      return SecurityStatus.secure;
    }

    // 1. Check if running in Debug Mode (Dart side)
    if (EndPoint.checkDebugMode && kDebugMode) {
      _logFailure(
        checkName: 'Debug Mode (Dart)',
        reason: 'التطبيق يعمل في وضع Debug (kDebugMode = true)',
        value: 'kDebugMode: true',
      );
      _blockReason = 'التطبيق يعمل في وضع التطوير والمحاكاة (Debug Mode).';
      _solutionSteps =
          'للبرمجة والتطوير: قم بتعطيل فحص kDebugMode مؤقتاً عبر تغيير EndPoint.checkDebugMode إلى false.\n\nللتشغيل النهائي: يجب بناء التطبيق بالنسخة النهائية (Release Build) عبر تشغيل الأمر:\nflutter run --release';
      return SecurityStatus.blocked;
    }

    if (!Platform.isAndroid) {
      // Return secure if not Android (non-Android platforms don't run this specific RASP)
      return SecurityStatus.secure;
    }

    try {
      final Map<dynamic, dynamic>? results = await _channel.invokeMethod(
        'checkSecurityEnvironment',
      );

      if (results == null) {
        _logFailure(
          checkName: 'Native Channel',
          reason: 'قناة الاتصال بالنظام (MethodChannel) أعادت قيمة فارغة.',
          value: 'null',
        );
        _blockReason = 'فشل في الاتصال بنظام الحماية الخاص بالهاتف.';
        _solutionSteps =
            '1. تأكد من أن جهازك يعمل بشكل طبيعي.\n2. أعد تشغيل التطبيق.\n3. إذا استمرت المشكلة، يرجى إعادة تثبيت التطبيق.';
        return SecurityStatus.blocked;
      }

      final bool isRooted = results['isRooted'] as bool? ?? false;
      final bool isEmulator = results['isEmulator'] as bool? ?? false;
      final bool isFridaDetected = results['isFridaDetected'] as bool? ?? false;
      final bool isDebuggerConnected =
          results['isDebuggerConnected'] as bool? ?? false;
      final bool isUsbDebuggingEnabled =
          results['isUsbDebuggingEnabled'] as bool? ?? false;
      final bool isSignatureValid =
          results['isSignatureValid'] as bool? ?? true;
      final bool isIntegrityValid =
          results['isIntegrityValid'] as bool? ?? true;
      final bool isNativeDebug = results['isNativeDebug'] as bool? ?? false;

      if (EndPoint.checkRoot && isRooted) {
        _logFailure(
          checkName: 'Root Detection',
          reason: 'تم اكتشاف صلاحيات الروت (Root) على هذا الجهاز.',
          value: 'isRooted: true',
        );
        _blockReason = 'تم اكتشاف صلاحيات الروت (Root) على هذا الجهاز.';
        _solutionSteps =
            '1. قم بإلغاء صلاحيات الروت (Unroot) من جهازك.\n2. استخدم تطبيقاً مثل Magisk لإخفاء الروت عن هذا التطبيق.\n3. أو قم بتشغيل التطبيق من جهاز ذكي غير معدّل أمنياً.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkEmulator && isEmulator) {
        _logFailure(
          checkName: 'Emulator Detection',
          reason: 'يُحظر تشغيل التطبيق على أجهزة المحاكاة (Emulator).',
          value: 'isEmulator: true',
        );
        _blockReason = 'يُحظر تشغيل التطبيق على أجهزة المحاكاة (Emulator).';
        _solutionSteps =
            '1. يرجى إغلاق برنامج المحاكاة.\n2. قم بتثبيت التطبيق وتشغيله على هاتف ذكي حقيقي (Android أو iOS).\n3. لا يمكن استخدام أجهزة الكمبيوتر أو البيئات الافتراضية لأسباب تتعلق بالخصوصية والأمان.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkFrida && isFridaDetected) {
        _logFailure(
          checkName: 'Frida/Hook Detection',
          reason: 'تم اكتشاف أدوات تلاعب أو حقن بالذاكرة (Frida).',
          value: 'isFridaDetected: true',
        );
        _blockReason = 'تم اكتشاف أدوات تلاعب أو حقن بالذاكرة (Frida).';
        _solutionSteps =
            '1. قم بإيقاف أو إلغاء تثبيت أي أدوات لحقن الذاكرة أو التلاعب بالنظام (مثل Frida أو Xposed).\n2. تأكد من عدم تشغيل أي سكريبتات فحص برمجية في الخلفية.\n3. أعد تشغيل الهاتف وحاول مجدداً.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkDebugger && isDebuggerConnected) {
        _logFailure(
          checkName: 'Debugger Connected',
          reason: 'تم اكتشاف اتصال بمصحح الأخطاء (Debugger).',
          value: 'isDebuggerConnected: true',
        );
        _blockReason = 'تم اكتشاف اتصال بمصحح الأخطاء (Debugger).';
        _solutionSteps =
            '1. قم بفصل الهاتف عن جهاز الكمبيوتر.\n2. أغلق بيئة التطوير (IDE) المتصلة بالتطبيق.\n3. أعد فتح التطبيق بشكل مستقل من الهاتف.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkUsbDebugging && isUsbDebuggingEnabled) {
        _logFailure(
          checkName: 'USB Debugging Enabled',
          reason: 'تم اكتشاف تفعيل خيار USB Debugging.',
          value: 'isUsbDebuggingEnabled: true',
        );
        _blockReason = 'تم اكتشاف تفعيل خيار تصحيح أخطاء USB.';
        _solutionSteps =
            '1. افتح إعدادات الهاتف (Settings).\n2. اذهب إلى خيارات المطور (Developer Options).\n3. قم بإيقاف تفعيل خيار "تصحيح أخطاء USB" (USB Debugging).\n4. أو قم بإيقاف خيارات المطور بالكامل من الأعلى.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkNativeDebug && isNativeDebug) {
        _logFailure(
          checkName: 'Native Debug Mode',
          reason: 'تم تشغيل التطبيق في وضع debuggable على نظام أندرويد.',
          value: 'isNativeDebug: true',
        );
        _blockReason = 'تم تشغيل التطبيق في وضع debuggable على نظام أندرويد.';
        _solutionSteps =
            '1. يجب بناء التطبيق بالنسخة النهائية للإنتاج (Release Build).\n2. تأكد من تعيين flag الحماية debuggable = false في ملف AndroidManifest.xml.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkSignature && !isSignatureValid) {
        _logFailure(
          checkName: 'App Signature Verification',
          reason: 'توقيع التطبيق غير صحيح أو تم التلاعب به.',
          value: 'isSignatureValid: false',
        );
        _blockReason = 'توقيع التطبيق غير صحيح (Invalid App Signature).';
        _solutionSteps =
            '1. تم الكشف عن أن التطبيق قد تمت إعادة حزمته وتوقيعه بمفتاح غير مصرح به.\n2. يرجى تحميل التطبيق وتثبيته حصرياً من متجر Google Play الرسمي أو قنوات التوزيع المعتمدة.';
        return SecurityStatus.blocked;
      }

      if (EndPoint.checkIntegrity && !isIntegrityValid) {
        _logFailure(
          checkName: 'App Integrity Check',
          reason: 'فشل فحص سلامة التطبيق (Integrity Check).',
          value: 'isIntegrityValid: false',
        );
        _blockReason = 'فشل فحص سلامة التطبيق (App Integrity Compromised).';
        _solutionSteps =
            '1. تأكد من أنك لا تستخدم تطبيقات استنساخ مثل Parallel Space أو Dual App.\n2. قم بإلغاء تثبيت النسخ المستنسخة من التطبيق وتشغيل النسخة الأصلية فقط.';
        return SecurityStatus.blocked;
      }

      // debugPrint('Security check PASSED. Proceeding to application startup...');
      return SecurityStatus.secure;
    } catch (e) {
      _logFailure(
        checkName: 'Security Exception',
        reason: 'حدث خطأ أثناء إجراء فحص الأمان: $e',
        value: e.toString(),
      );
      _blockReason = 'حدث خطأ غير متوقع أثناء فحص أمان الجهاز.';
      _solutionSteps =
          '1. أعد تشغيل الهاتف الخاص بك.\n2. تحقق من تحديث نظام التشغيل لأحدث إصدار.\n3. أعد فتح التطبيق.';
      return SecurityStatus.blocked;
    }
  }

  static void _logFailure({
    required String checkName,
    required String reason,
    required String value,
  }) {
    final now = DateTime.now();
    // debugPrint('==================================================');
    // debugPrint('🚨 SECURITY AUDIT FAILURE 🚨');
    // debugPrint('Time: ${now.toIso8601String()}');
    // debugPrint('Check Failed: $checkName');
    // debugPrint('Reason: $reason');
    // debugPrint('Offending Value: $value');
    // debugPrint('==================================================');
  }
}
