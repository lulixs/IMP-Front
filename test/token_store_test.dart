import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/api/token_store.dart';

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
}
