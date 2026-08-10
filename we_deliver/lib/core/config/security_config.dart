import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:we_deliver/core/services/firebase_config_service.dart';

/// Centralized security configuration for the application.
/// Ensures all sensitive security variables, environments, and bypasses
/// are declared in a single, well-guarded file.
class SecurityConfig {
  SecurityConfig._();

  static String _decrypt(String obfuscated) {
    final reversed = obfuscated.split('').reversed.join('');
    return utf8.decode(base64.decode(reversed));
  }

  /// Obfuscated allowed fingerprints to hide them from static scanner tools.
  static final List<String> _obfuscatedDefaultFingerprints = [
    "==QM0I2Y2gzM5E2NjZWN2MzNzIjMlhDZ0UjY5cTMhlzY4AzNmNzYiJDM1AjYxcjZlRDO3Y2NhN2N3IWZwMTZjFTM",
    "==AM5EjYjZTO1cTM4cjMiFjYzcDO0M2NxAzN5YGO3UmZyQWZxEDZycTM4YWYmVGOyADOhBjN0UWYhVTM4YjMlRDO",
  ];

  static final List<String> _obfuscatedBackupFingerprints = [
    "==QN1gjYyUDO3IWM5kTN5QTYjRzM5IWO0YDNlFDNlF2NyQjM5ImZ2kTO4MGNmJmZhlDNxMWMjZGO5IDN0MGMiNTZ",
  ];

  /// Get allowed fingerprints dynamically. Merges Remote Config values
  /// (for real-time rotation) with hardcoded fallbacks and backup fingerprints.
  static List<String> get allowedFingerprints {
    final List<String> remotePins = FirebaseConfigService.sslAllowedFingerprints;
    
    final localDefaults = _obfuscatedDefaultFingerprints.map(_decrypt).toList();
    final localBackups = _obfuscatedBackupFingerprints.map(_decrypt).toList();

    if (remotePins.isEmpty) {
      return List.unmodifiable([...localDefaults, ...localBackups]);
    }
    return List.unmodifiable([...remotePins, ...localBackups]);
  }

  /// Verifies if a given host qualifies for SSL Pinning bypasses.
  /// Bypasses are STRICTLY restricted to Debug Mode / Development Environments
  /// and are completely disabled in Release builds.
  static bool shouldBypassPinning(String host) {
    // Release builds must NEVER allow any SSL bypasses
    if (const bool.fromEnvironment('dart.vm.product') || !kDebugMode) {
      return false;
    }

    final lowercaseHost = host.toLowerCase();
    
    // Check loopback and private subnets in debug/development builds
    return lowercaseHost == 'localhost' ||
        lowercaseHost == '127.0.0.1' ||
        lowercaseHost == '10.0.2.2' || // Android Emulator Loopback
        lowercaseHost.startsWith('192.168.') ||
        lowercaseHost.startsWith('10.') ||
        lowercaseHost.startsWith('172.');
  }

  /// Constant-time comparison for strings to prevent timing attacks.
  static bool safeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Logs security information securely.
  /// Guarantees that logs are completely stripped in Release builds.
  static void logSecurityEvent(String message) {
    // 1. Asserts are completely compiled out in Release builds
    assert(() {
      // ignore: avoid_print
      print('🛡️ [Security Audit Log]: $message');
      return true;
    }());

    // 2. Extra compile-time / debug flag check to ensure no print execution in production
    if (kDebugMode) {
      // ignore: avoid_print
      print('🛡️ [Security Audit Log]: $message');
    }
  }
}
