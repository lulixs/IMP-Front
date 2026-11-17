import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/api/auth_api.dart';
import 'package:imp_app/api/token_store.dart';
import 'package:imp_app/session.dart';

void main() {
  // The tablet is signed in, so signing out has something to forget.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'deviceToken': 'device-abc',
      'sessionToken': 'session-xyz',
      'employeeId': '1',
      'employeeName': 'Dan Finkle',
    });
  });

  // A Session whose fake server writes down each request and answers with this status and body.
  Session sessionReplying(int status, String body, [List<http.Request>? sent]) {
    final client = MockClient((request) async {
      sent?.add(request);
      return http.Response(body, status);
    });
    return Session(
      employeeId: 1,
      employeeName: 'Dan Finkle',
      auth: AuthApi(ApiClient(client: client)),
    );
  }

  test('A new session keeps the employee and starts with Master mode off', () {
    final session = sessionReplying(204, '');

    expect(session.employeeId, 1);
    expect(session.employeeName, 'Dan Finkle');
    expect(session.masterMode, isFalse);
  });

  test('Setting Master mode changes it and tells listeners, but only when it actually changes', () {
    final session = sessionReplying(204, '');
    var told = 0;
    session.addListener(() => told++);

    session.masterMode = true;
    expect(session.masterMode, isTrue);
    expect(told, 1);

    session.masterMode = true;
    expect(told, 1, reason: 'already on, so nothing changed');

    session.masterMode = false;
    expect(session.masterMode, isFalse);
    expect(told, 2);
  });

  group('turnOnMasterMode', () {
    test('Sends the Master email and password with the session token', () async {
      final sent = <http.Request>[];
      await sessionReplying(204, '', sent).turnOnMasterMode('manager@example.com', 'password123');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/master-mode');
      expect(sent.single.headers['authorization'], 'Bearer session-xyz');
      expect(jsonDecode(sent.single.body), {'email': 'manager@example.com', 'password': 'password123'});
    });

    test('Turns Master mode on, and tells listeners, once the server says yes', () async {
      final session = sessionReplying(204, '');
      var told = 0;
      session.addListener(() => told++);

      final error = await session.turnOnMasterMode('manager@example.com', 'password123');

      expect(error, isNull);
      expect(session.masterMode, isTrue);
      expect(told, 1);
    });

    test('A refused password hands back the sentence and leaves Master mode off', () async {
      final session = sessionReplying(401, '{"error": "Incorrect email or password. Try again."}');

      final error = await session.turnOnMasterMode('manager@example.com', 'nope');

      expect(error, 'Incorrect email or password. Try again.');
      expect(session.masterMode, isFalse);
    });

    test('No connection hands back the sentence and leaves Master mode off', () async {
      final session = Session(
        employeeId: 1,
        employeeName: 'Dan Finkle',
        auth: AuthApi(ApiClient(client: MockClient((request) async => throw http.ClientException('No connection')))),
      );

      final error = await session.turnOnMasterMode('manager@example.com', 'password123');

      expect(error, "Can't reach the server. Check the connection and try again.");
      expect(session.masterMode, isFalse);
    });
  });

  group('turnOffMasterMode', () {
    test('Sends DELETE /api/master-mode with the session token, then turns it off', () async {
      final sent = <http.Request>[];
      final session = sessionReplying(204, '', sent)..masterMode = true;

      await session.turnOffMasterMode();

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/master-mode');
      expect(sent.single.headers['authorization'], 'Bearer session-xyz');
      expect(session.masterMode, isFalse);
    });

    test('If the server fails, it throws and Master mode stays on', () async {
      final session = sessionReplying(500, '{"error": "Something went wrong. Please try again later."}')
        ..masterMode = true;

      await expectLater(session.turnOffMasterMode(), throwsA(isA<ApiException>()));

      expect(session.masterMode, isTrue);
    });
  });

  group('signOut', () {
    test('Sends DELETE /api/sessions/current and forgets the saved session and employee', () async {
      final sent = <http.Request>[];
      await sessionReplying(204, '', sent).signOut();

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/sessions/current');
      expect(sent.single.headers['authorization'], 'Bearer session-xyz');
      final tokens = TokenStore();
      expect(await tokens.readSessionToken(), isNull);
      expect(await tokens.readEmployee(), isNull);
      expect(await tokens.readDeviceToken(), 'device-abc');
    });

    test('If the server fails, it throws and the saved session stays', () async {
      final session = sessionReplying(500, '{"error": "Something went wrong. Please try again later."}');

      await expectLater(session.signOut(), throwsA(isA<ApiException>()));

      expect(await TokenStore().readSessionToken(), 'session-xyz');
    });
  });
}
