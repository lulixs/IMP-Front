import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';

void main() {
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
}
