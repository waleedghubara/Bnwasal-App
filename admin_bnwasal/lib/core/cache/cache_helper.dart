import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCacheHelper {
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  //! Get Data as String
  Future<String?> getDataString({required String key}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('SecureCacheHelper getDataString error for key "$key": $e');
      return null;
    }
  }

  //! Save Data based on type (converted to String)
  Future<void> saveData({required String key, required dynamic value}) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
    } catch (e) {
      debugPrint('SecureCacheHelper saveData error for key "$key": $e');
    }
  }

  //! Get Data (always returns String)
  Future<String?> getData({required String key}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('SecureCacheHelper getData error for key "$key": $e');
      return null;
    }
  }

  //! Remove Data
  Future<void> removeData({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('SecureCacheHelper removeData error for key "$key": $e');
    }
  }

  //! Check if Key exists (if read returns null = doesn't exist)
  Future<bool> containsKey({required String key}) async {
    try {
      String? value = await _secureStorage.read(key: key);
      return value != null;
    } catch (e) {
      debugPrint('SecureCacheHelper containsKey error for key "$key": $e');
      return false;
    }
  }

  //! Clear All Data
  Future<void> clearData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('SecureCacheHelper clearData error: $e');
    }
  }

  //! Put Data (alias for saveData)
  Future<void> put({required String key, required dynamic value}) async {
    await saveData(key: key, value: value);
  }
}
