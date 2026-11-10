import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';

// ApiClient fetches data from the backend: server address, timeout, and error handling
class ApiClient {
  final http.Client _http;

  // Uses provided client or creates a new one
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  // Sends request through _request based on method
  Future<dynamic> get(String path, {required String screen}) async {
    return _request('GET', path, screen: screen);
  }

  Future<dynamic> post(String path, {required String screen, Object? body}) async {
    return _request('POST', path, screen: screen, body: body);
  }

  Future<dynamic> put(String path, {required String screen, Object? body}) async {
    return _request('PUT', path, screen: screen, body: body);
  }

  Future<dynamic> delete(String path, {required String screen}) async {
    return _request('DELETE', path, screen: screen);
  }

  // Sends request to server based on user action, applies timeout, and converts failures into ApiExceptions
  Future<dynamic> _request(String method, String path, {required String screen, Object? body}) async {
    final url = Uri.parse('$apiBaseUrl$path');
    final http.Response res;
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final headers = <String, String>{};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    try {
      // Setting which trip to take based on request type
      final Future<http.Response> trip = switch (method) {
        'GET' => _http.get(url, headers: headers),
        'POST' => _http.post(url, headers: headers, body: encodedBody),
        'PUT' => _http.put(url, headers: headers, body: encodedBody),
        'DELETE' => _http.delete(url, headers: headers),
        _ => throw ArgumentError('Unknown trip request: $method'),
      };
      res = await trip.timeout(apiTimeout);
    } on TimeoutException {
      throw ApiException(
        'Server took too long to respond. Please try again.',
        screen: screen,
      );
    } on http.ClientException {
      // Message changes when active in store: ... Check the tablet's internet connection
      throw ApiException(
        'Connection to server failed. Ensure the server is running.',
        screen: screen,
      );
    }
    if (res.statusCode >= 500) {
      throw ApiException(
        'There is an issue with the server (error ${res.statusCode}).',
        screen: screen,
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        'The request was not accepted (error ${res.statusCode}).',
        screen: screen,
        statusCode: res.statusCode,
      );
    }
    // returns null when body is empty
    if (res.body.isEmpty) {
      return null;
    }
    // Decodes JSON text into Dart data
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw ApiException(
        'The server sent back data that could not be read.',
        screen: screen,
        statusCode: res.statusCode,
      );
    }
  }
}
