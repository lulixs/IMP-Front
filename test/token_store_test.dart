import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/api/token_store.dart';
import 'package:imp_app/models/employee.dart';

void main() {
  // Tests don't have the tablet's locked storage. This swaps in an empty stand-in before each test.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Starts with no tokens', () async {
    final tokens = TokenStore();

    expect(await tokens.readDeviceToken(), isNull);
    expect(await tokens.readSessionToken(), isNull);
  });

  test('Saves and reads back each token separately', () async {
    final tokens = TokenStore();

    await tokens.saveDeviceToken('device-abc');
    await tokens.saveSessionToken('session-xyz');

    expect(await tokens.readDeviceToken(), 'device-abc');
    expect(await tokens.readSessionToken(), 'session-xyz');
  });

  test('Signing out deletes the session token but keeps the device token', () async {
    final tokens = TokenStore();
    await tokens.saveDeviceToken('device-abc');
    await tokens.saveSessionToken('session-xyz');

    await tokens.deleteSessionToken();

    expect(await tokens.readSessionToken(), isNull);
    expect(await tokens.readDeviceToken(), 'device-abc');
  });

  test('Deleting the device token leaves the session token alone', () async {
    final tokens = TokenStore();
    await tokens.saveDeviceToken('device-abc');
    await tokens.saveSessionToken('session-xyz');

    await tokens.deleteDeviceToken();

    expect(await tokens.readDeviceToken(), isNull);
    expect(await tokens.readSessionToken(), 'session-xyz');
  });

  group('Signed-in employee', () {
    test('Starts with no employee', () async {
      expect(await TokenStore().readEmployee(), isNull);
    });

    test('Saves and reads back the employee, with the id as a number again', () async {
      final tokens = TokenStore();

      await tokens.saveEmployee(const Employee(id: 4, name: 'Grace Kim'));

      final employee = await tokens.readEmployee();
      expect(employee?.id, 4);
      expect(employee?.name, 'Grace Kim');
    });

    test('Saving again replaces the employee', () async {
      final tokens = TokenStore();
      await tokens.saveEmployee(const Employee(id: 4, name: 'Grace Kim'));

      await tokens.saveEmployee(const Employee(id: 2, name: 'Thomas Anos'));

      final employee = await tokens.readEmployee();
      expect(employee?.id, 2);
      expect(employee?.name, 'Thomas Anos');
    });

    test('Reads as no employee when only the id is saved', () async {
      FlutterSecureStorage.setMockInitialValues({'employeeId': '4'});

      expect(await TokenStore().readEmployee(), isNull);
    });

    test('Reads as no employee when only the name is saved', () async {
      FlutterSecureStorage.setMockInitialValues({'employeeName': 'Grace Kim'});

      expect(await TokenStore().readEmployee(), isNull);
    });

    test('Deleting the session token forgets the employee too, and keeps the device token', () async {
      final tokens = TokenStore();
      await tokens.saveDeviceToken('device-abc');
      await tokens.saveSessionToken('session-xyz');
      await tokens.saveEmployee(const Employee(id: 4, name: 'Grace Kim'));

      await tokens.deleteSessionToken();

      expect(await tokens.readEmployee(), isNull);
      expect(await tokens.readSessionToken(), isNull);
      expect(await tokens.readDeviceToken(), 'device-abc');
    });

    test('Deleting the device token keeps the employee', () async {
      final tokens = TokenStore();
      await tokens.saveEmployee(const Employee(id: 4, name: 'Grace Kim'));

      await tokens.deleteDeviceToken();

      expect((await tokens.readEmployee())?.name, 'Grace Kim');
    });
  });
}
