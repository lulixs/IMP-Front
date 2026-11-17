import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/api/auth_api.dart';
import 'package:imp_app/api/token_store.dart';

// Each sign-in call against IMP-Back docs/api/auth.md: its method and path, the token it sends, its body,
// what it returns, and what it saves.
void main() {
  late List<http.Request> sent;
  late TokenStore tokens;

  // The tablet starts with old tokens saved, so each test shows which one goes out and what gets replaced.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'deviceToken': 'old-device',
      'sessionToken': 'old-session',
      'employeeId': '9',
      'employeeName': 'Old Name',
    });
    sent = [];
    tokens = TokenStore();
  });

  // An AuthApi whose fake server writes down every request and answers with this status and body.
  AuthApi replying(int status, String body) {
    final client = MockClient((request) async {
      sent.add(request);
      return http.Response(body, status);
    });
    return AuthApi(
      ApiClient(client: client, tokens: tokens),
      tokens: tokens,
    );
  }

  String? sentToken() => sent.single.headers['authorization'];
  Object? sentBody() => sent.single.body.isEmpty ? null : jsonDecode(sent.single.body);

  const employeeJson = '{"id": 1, "name": "Daniel Finkle"}';

  group('isSetUp', () {
    test('GET /api/setup/status with no token', () async {
      await replying(200, '{"isSetUp": true}').isSetUp();

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/setup/status');
      expect(sentToken(), isNull);
    });

    test('Returns what the server says', () async {
      expect(await replying(200, '{"isSetUp": true}').isSetUp(), isTrue);
      expect(await replying(200, '{"isSetUp": false}').isSetUp(), isFalse);
    });
  });

  group('setUp', () {
    const reply = '{"deviceToken": "new-device", "sessionToken": "new-session", "employee": $employeeJson}';

    Future<void> callIt(AuthApi auth) {
      return auth.setUp('manager@example.com', 'password123', 'Front desk tablet', 'Daniel Finkle', '012345');
    }

    test('POST /api/setup with no token and the five fields', () async {
      await callIt(replying(201, reply));

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/setup');
      expect(sentToken(), isNull);
      expect(sentBody(), {
        'masterEmail': 'manager@example.com',
        'masterPassword': 'password123',
        'tabletName': 'Front desk tablet',
        'employeeName': 'Daniel Finkle',
        'employeePin': '012345',
      });
    });

    test('Returns both tokens and the employee', () async {
      final result = await replying(
        201,
        reply,
      ).setUp('manager@example.com', 'password123', 'Front desk tablet', 'Daniel Finkle', '012345');

      expect(result.deviceToken, 'new-device');
      expect(result.sessionToken, 'new-session');
      expect(result.employee.id, 1);
      expect(result.employee.name, 'Daniel Finkle');
    });

    test('Saves both tokens and the employee', () async {
      await callIt(replying(201, reply));

      expect(await tokens.readDeviceToken(), 'new-device');
      expect(await tokens.readSessionToken(), 'new-session');
      expect((await tokens.readEmployee())?.name, 'Daniel Finkle');
    });

    test('A refused setup throws the server sentence and saves nothing', () async {
      final auth = replying(409, '{"error": "This store is already set up. Set up this tablet instead."}');

      await expectLater(callIt(auth), throwsA(isA<ApiException>()));

      expect(await tokens.readDeviceToken(), 'old-device');
      expect(await tokens.readSessionToken(), 'old-session');
    });
  });

  group('addTablet', () {
    const reply = '{"deviceToken": "new-device", "device": {"id": 2, "name": "Stockroom tablet"}}';

    test('POST /api/devices with no token, since the tablet has none yet', () async {
      await replying(201, reply).addTablet('Stockroom tablet', 'manager@example.com', 'password123');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/devices');
      expect(sentToken(), isNull);
      expect(sentBody(), {'tabletName': 'Stockroom tablet', 'email': 'manager@example.com', 'password': 'password123'});
    });

    test('Returns and saves the device token, and leaves the session alone', () async {
      final deviceToken = await replying(
        201,
        reply,
      ).addTablet('Stockroom tablet', 'manager@example.com', 'password123');

      expect(deviceToken, 'new-device');
      expect(await tokens.readDeviceToken(), 'new-device');
      expect(await tokens.readSessionToken(), 'old-session');
    });

    test('A wrong password throws and keeps the old device token', () async {
      final auth = replying(401, '{"error": "Incorrect email or password. Try again."}');

      await expectLater(
        auth.addTablet('Stockroom tablet', 'manager@example.com', 'nope'),
        throwsA(isA<ApiException>()),
      );

      expect(await tokens.readDeviceToken(), 'old-device');
    });
  });

  group('renewTablet', () {
    test('POST /api/devices/renew with the device token', () async {
      await replying(200, '{"deviceToken": "new-device"}').renewTablet('manager@example.com', 'password123');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/devices/renew');
      expect(sentToken(), 'Bearer old-device');
      expect(sentBody(), {'email': 'manager@example.com', 'password': 'password123'});
    });

    test('Returns the new device token and saves it in place of the old one', () async {
      final deviceToken = await replying(
        200,
        '{"deviceToken": "new-device"}',
      ).renewTablet('manager@example.com', 'password123');

      expect(deviceToken, 'new-device');
      expect(await tokens.readDeviceToken(), 'new-device');
    });
  });

  group('activeEmployees', () {
    test('GET /api/employees/active with the device token', () async {
      await replying(200, '{"employees": []}').activeEmployees();

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/employees/active');
      expect(sentToken(), 'Bearer old-device');
    });

    test('Returns every employee in the order the server sent', () async {
      final employees = await replying(
        200,
        '{"employees": [$employeeJson, {"id": 4, "name": "Grace Kim"}]}',
      ).activeEmployees();

      expect(employees.map((e) => e.id), [1, 4]);
      expect(employees.map((e) => e.name), ['Daniel Finkle', 'Grace Kim']);
    });

    test('An empty list is an empty list', () async {
      expect(await replying(200, '{"employees": []}').activeEmployees(), isEmpty);
    });
  });

  group('signIn', () {
    const reply = '{"sessionToken": "new-session", "employee": $employeeJson}';

    test('POST /api/sessions with the device token, the employee id, and the PIN as text', () async {
      await replying(200, reply).signIn(1, '012345');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/sessions');
      expect(sentToken(), 'Bearer old-device');
      expect(sentBody(), {'employeeId': 1, 'pin': '012345'});
    });

    test('Returns the session token and the employee', () async {
      final result = await replying(200, reply).signIn(1, '111111');

      expect(result.sessionToken, 'new-session');
      expect(result.employee.id, 1);
      expect(result.employee.name, 'Daniel Finkle');
    });

    test('Saves the session token and the employee, and keeps the device token', () async {
      await replying(200, reply).signIn(1, '111111');

      expect(await tokens.readSessionToken(), 'new-session');
      expect((await tokens.readEmployee())?.id, 1);
      expect((await tokens.readEmployee())?.name, 'Daniel Finkle');
      expect(await tokens.readDeviceToken(), 'old-device');
    });

    test('A wrong PIN throws the server sentence and keeps the old session', () async {
      final auth = replying(401, '{"error": "Incorrect PIN. Try again."}');

      try {
        await auth.signIn(1, '000000');
        fail('Expected an ApiException');
      } on ApiException catch (e) {
        expect(e.message, 'Incorrect PIN. Try again.');
      }
      expect(await tokens.readSessionToken(), 'old-session');
      expect((await tokens.readEmployee())?.name, 'Old Name');
    });
  });

  group('signOut', () {
    test('DELETE /api/sessions/current with the session token', () async {
      await replying(204, '').signOut();

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/sessions/current');
      expect(sentToken(), 'Bearer old-session');
      expect(sentBody(), isNull);
    });

    test('Forgets the session and the employee, and keeps the device token', () async {
      await replying(204, '').signOut();

      expect(await tokens.readSessionToken(), isNull);
      expect(await tokens.readEmployee(), isNull);
      expect(await tokens.readDeviceToken(), 'old-device');
    });

    test('If the server fails, the session is kept, since the server still has it', () async {
      final auth = replying(500, '{"error": "Something went wrong. Please try again later."}');

      await expectLater(auth.signOut(), throwsA(isA<ApiException>()));

      expect(await tokens.readSessionToken(), 'old-session');
    });
  });

  group('Master mode', () {
    test('masterModeOn is POST /api/master-mode with the session token and the Master email and password', () async {
      await replying(204, '').masterModeOn('manager@example.com', 'password123');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/master-mode');
      expect(sentToken(), 'Bearer old-session');
      expect(sentBody(), {'email': 'manager@example.com', 'password': 'password123'});
    });

    test('masterModeOff is DELETE /api/master-mode with the session token', () async {
      await replying(204, '').masterModeOff();

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/master-mode');
      expect(sentToken(), 'Bearer old-session');
    });

    test('Neither changes the saved tokens', () async {
      await replying(204, '').masterModeOn('manager@example.com', 'password123');
      await replying(204, '').masterModeOff();

      expect(await tokens.readDeviceToken(), 'old-device');
      expect(await tokens.readSessionToken(), 'old-session');
    });

    test('A wrong Master password throws the server sentence', () async {
      final auth = replying(401, '{"error": "Incorrect email or password. Try again."}');

      await expectLater(auth.masterModeOn('manager@example.com', 'nope'), throwsA(isA<ApiException>()));
    });
  });
}
