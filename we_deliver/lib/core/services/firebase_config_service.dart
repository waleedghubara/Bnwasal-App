// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class FirebaseConfigService {
  FirebaseConfigService._();

  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Helper to decode parameter names at runtime to hide them from static analysis.
  static String _decryptParamName(String obfuscated) {
    final reversed = obfuscated.split('').reversed.join('');
    return utf8.decode(base64.decode(reversed));
  }

  /// Initializes Remote Config, sets fetch settings and defaults, and attempts
  /// to fetch and activate the latest keys.
  static Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));

      // Set empty/dummy defaults using obfuscated parameter keys.
      // We don't use 'const' map here because we invoke a dynamic helper.
      await _remoteConfig.setDefaults({
        _decryptParamName('==Qelt2XpBXYfNHch12Xlx2Zv92Z'): '', // google_maps_api_key
        _decryptParamName('5V2afNWa0FGdz91b0BXeyN2XpBXY'): '', // api_crypto_static_key
        _decryptParamName('=U2chJHawN3chB3Xy9GeflHdpJXdjV2c'): '', // security_xor_passphrase
        _decryptParamName('zRnbpJHcyV2ZulmZfRWZ39GbsF2XsN3c'): '["11ce30eb77ca7f784ef71b0502bc3f708c9a179b54d8e2237365fc7a9386cb41", "84e26815aae460a8028efaf8172d11ed2fe78f97017c4873b1b27817596cb190"]', // ssl_allowed_fingerprints
      });

      // Fetch from remote config and activate the fetched values
      final success = await _remoteConfig.fetchAndActivate();
      if (success) {
        print('🔥 Firebase Remote Config: Fetched and activated new config.');
      } else {
        print('🔥 Firebase Remote Config: Activated cached config (no new values fetched).');
      }
    } catch (e) {
      print('❌ Firebase Remote Config initialization failed: $e');
    }
  }

  /// The obfuscated Google Maps API Key
  static String get googleMapsApiKey {
    final key = _decryptParamName('==Qelt2XpBXYfNHch12Xlx2Zv92Z');
    final value = _remoteConfig.getString(key);
    if (value.isEmpty) {
      print('⚠️ Warning: google_maps_api_key is empty in Firebase Remote Config.');
    }
    return value;
  }

  /// The API Cryptography Static Key
  static String get apiCryptoStaticKey {
    final key = _decryptParamName('5V2afNWa0FGdz91b0BXeyN2XpBXY');
    final value = _remoteConfig.getString(key);
    if (value.isEmpty) {
      print('⚠️ Warning: api_crypto_static_key is empty in Firebase Remote Config.');
    }
    return value;
  }

  /// The Security XOR Passphrase
  static String get securityXorPassphrase {
    final key = _decryptParamName('=U2chJHawN3chB3Xy9GeflHdpJXdjV2c');
    final value = _remoteConfig.getString(key);
    if (value.isEmpty) {
      print('⚠️ Warning: security_xor_passphrase is empty in Firebase Remote Config.');
    }
    return value;
  }

  /// The SSL Allowed Fingerprints
  static List<String> get sslAllowedFingerprints {
    final key = _decryptParamName('zRnbpJHcyV2ZulmZfRWZ39GbsF2XsN3c');
    final value = _remoteConfig.getString(key);
    if (value.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = json.decode(value);
      return decoded.map((e) => e.toString().trim().toLowerCase()).toList();
    } catch (e) {
      return [];
    }
  }
}
