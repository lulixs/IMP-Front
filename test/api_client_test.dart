import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/api/token_store.dart';

void main() {
  // ApiClient reads tokens from locked storage, which tests don't have. This swaps in an empty stand-in.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Each verb sends its own method', () async {
    // The fake server writes down the method of every request it gets.
    final methods = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        methods.add(request.method);
        return http.Response('{}', 200);
      }),
    );

    await api.get('/api/boxes/1', screen: 'Test');
    await api.post('/api/boxes', screen: 'Test', body: {'categoryId': 1});
    await api.put('/api/boxes/1', screen: 'Test', body: {'categoryId': 1});
    await api.delete('/api/boxes/1', screen: 'Test');

    expect(methods, ['GET', 'POST', 'PUT', 'DELETE']);
  });

  test('POST sends the body as JSON with a Content-Type label', () async {
    // The fake server keeps the request so the test can open it afterward.
    late http.Request sent;
    final api = ApiClient(
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"sessionToken":"abc"}', 200);
      }),
    );

    await api.post(
      '/api/sessions',
      screen: 'Test',
      body: {'employeeId': 1, 'pin': '111111'},
    );

    expect(sent.method, 'POST');
    expect(jsonDecode(sent.body), {'employeeId': 1, 'pin': '111111'});
    // The http package adds "; charset=utf-8" to the end of the label.
    expect(sent.headers['content-type'], startsWith('application/json'));
  });

  test('GET sends no body and no Content-Type label', () async {
    late http.Request sent;
    final api = ApiClient(
      client: MockClient((request) async {
        sent = request;
        return http.Response('{}', 200);
      }),
    );

    await api.get('/api/dashboard', screen: 'Test');

    expect(sent.body, isEmpty);
    expect(sent.headers['content-type'], isNull);
  });

  test('An empty reply returns null instead of failing', () async {
    // Switch user answers 204 with nothing inside.
    final api = ApiClient(
      client: MockClient((request) async => http.Response('', 204)),
    );

    final result = await api.delete('/api/sessions/current', screen: 'Test');

    expect(result, isNull);
  });

  test('A JSON reply is still unpacked into Dart data', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response('{"id":7,"name":"Coats"}', 200),
      ),
    );

    final result = await api.get('/api/categories/7', screen: 'Test');

    expect(result, {'id': 7, 'name': 'Coats'});
  });

  test('An error reply uses the server sentence and keeps its code', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          '{"error":"You\'ve been signed out. Sign in again.","code":"sessionEnded"}',
          401,
        ),
      ),
    );

    try {
      await api.get('/api/dashboard', screen: 'Test');
      fail('Expected an ApiException');
    } on ApiException catch (e) {
      expect(e.message, "You've been signed out. Sign in again.");
      expect(e.code, 'sessionEnded');
      expect(e.statusCode, 401);
    }
  });

  test('An error reply with no body falls back to ApiClient\'s own sentence', () async {
    final api = ApiClient(
      client: MockClient((request) async => http.Response('', 500)),
    );

    try {
      await api.get('/api/dashboard', screen: 'Test');
      fail('Expected an ApiException');
    } on ApiException catch (e) {
      expect(e.message, 'There is an issue with the server (error 500).');
      expect(e.code, isNull);
    }
  });

  group('Token header', () {
    // The tablet has both tokens saved, so each test shows which one gets picked.
    late http.Request sent;
    late ApiClient api;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'deviceToken': 'device-abc', 'sessionToken': 'session-xyz'});
      api = ApiClient(
        client: MockClient((request) async {
          sent = request;
          return http.Response('{}', 200);
        }),
        tokens: TokenStore(),
      );
    });

    test('Sends the session token by default', () async {
      await api.get('/api/dashboard', screen: 'Test');

      expect(sent.headers['authorization'], 'Bearer session-xyz');
    });

    test('Sends the device token when asked', () async {
      await api.post(
        '/api/sessions',
        screen: 'Test',
        body: {'employeeId': 1, 'pin': '111111'},
        token: TokenType.device,
      );

      expect(sent.headers['authorization'], 'Bearer device-abc');
    });

    test('Sends no token when the endpoint needs none', () async {
      await api.get('/api/setup/status', screen: 'Test', token: TokenType.none);

      expect(sent.headers['authorization'], isNull);
    });
  });

  test('Sends no Authorization header when the tablet has no token yet', () async {
    late http.Request sent;
    final api = ApiClient(
      client: MockClient((request) async {
        sent = request;
        return http.Response('{}', 200);
      }),
    );

    await api.get('/api/dashboard', screen: 'Test');

    expect(sent.headers['authorization'], isNull);
  });
}
