import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/employee.dart';

// Keeps the device token, the session token, and the signed-in employee in lcoked storage
// Only file that touches flutter_secure_storage
class TokenStore {
  static const _deviceKey = 'deviceToken';
  static const _sessionKey = 'sessionToken';
  static const _employeeIdKey = 'employeeId';
  static const _employeeNameKey = 'employeeName';

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

  // Also forgets the signed-in employee, since they leave with the session
  Future<void> deleteSessionToken() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _employeeIdKey);
    await _storage.delete(key: _employeeNameKey);
  }

  // The signed-in employee, saved next to the session token so a restart can show their name
  // without asking the server. Storage only holds text, so the id is saved as a string
  Future<void> saveEmployee(Employee employee) async {
    await _storage.write(key: _employeeIdKey, value: employee.id.toString());
    await _storage.write(key: _employeeNameKey, value: employee.name);
  }

  // Null if no employee is saved
  Future<Employee?> readEmployee() async {
    final id = await _storage.read(key: _employeeIdKey);
    final name = await _storage.read(key: _employeeNameKey);
    if (id == null || name == null) return null;
    return Employee(id: int.parse(id), name: name);
  }
}
