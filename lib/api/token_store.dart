import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Keeps the device token and session token in lcoked storage
// Only file that touches flutter_secure_storage
class TokenStore {
  static const _deviceKey = 'deviceToken';
  static const _sessionKey = 'sessionToken';

  final FlutterSecureStorage _storage;

  // Uses provided storage or the tablet's real locked storage
  TokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  // Device token, lasts 90 days 
  Future<String?> readDeviceToken() {
    return _storage.read(key: _deviceKey);
  }

  Future<void> saveDeviceToken(String token) {
    return _storage.write(key: _deviceKey, value: token);
  }

  Future<void> deleteDeviceToken() {
    return _storage.delete(key: _deviceKey);
  }

  // Session token, lasts 12 hours
  Future<String?> readSessionToken() {
    return _storage.read(key: _sessionKey);
  }

  Future<void> saveSessionToken(String token) {
    return _storage.write(key: _sessionKey, value: token);
  }

  Future<void> deleteSessionToken() {
    return _storage.delete(key: _sessionKey);
  } 
}
