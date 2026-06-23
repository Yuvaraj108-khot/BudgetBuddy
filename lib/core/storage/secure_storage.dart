import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const String _keyToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyPinSet = 'is_pin_set';
  static const String _keyPinVerified = 'is_pin_verified';
  static const String _keySmsSync = 'is_sms_sync_enabled';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';

  // Tokens
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // Profile
  static Future<void> saveUserProfile(String name, String email) async {
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserEmail, value: email);
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  // App PIN Settings
  static Future<void> setPinConfigured(bool isSet) async {
    await _storage.write(key: _keyPinSet, value: isSet ? 'true' : 'false');
  }

  static Future<bool> isPinConfigured() async {
    final val = await _storage.read(key: _keyPinSet);
    return val == 'true';
  }

  static Future<void> setPinVerified(bool verified) async {
    await _storage.write(key: _keyPinVerified, value: verified ? 'true' : 'false');
  }

  static Future<bool> isPinVerified() async {
    final val = await _storage.read(key: _keyPinVerified);
    return val == 'true';
  }

  // SMS Import Preference (Defaults to true, but user can opt-out)
  static Future<void> setSmsSyncEnabled(bool enabled) async {
    await _storage.write(key: _keySmsSync, value: enabled ? 'true' : 'false');
  }

  static Future<bool> isSmsSyncEnabled() async {
    final val = await _storage.read(key: _keySmsSync);
    return val != 'false'; // Default to true if not set
  }

  // Clear Session (Logout)
  static Future<void> clearAuth() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyPinVerified);
  }
}
