import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';
import 'token_store.dart';

// Diffrent types of tokens a request can carry
enum TokenType { none, device, session }

// ApiClient fetches data from the backend: server address, timeout, and error handling
class ApiClient {
  final http.Client _http;
  final TokenStore _tokens;

  // Uses provided client and token store, or creates new ones
  ApiClient({http.Client? client, TokenStore? tokens})
    : _http = client ?? http.Client(), _tokens = tokens ?? TokenStore();

  // Sends request through _request based on method. Most endpoints need the session token, so it is the default
  Future<dynamic> get(String path, {required String screen, TokenType token = TokenType.session}) async {
    return _request('GET', path, screen: screen, token: token);
  }

  Future<dynamic> post(String path, {required String screen, Object? body, TokenType token = TokenType.session}) async {
    return _request('POST', path, screen: screen, body: body, token: token);
  }

  Future<dynamic> put(String path, {required String screen, Object? body, TokenType token = TokenType.session}) async {
    return _request('PUT', path, screen: screen, body: body, token: token);
  }

  Future<dynamic> delete(String path, {required String screen, TokenType token = TokenType.session}) async {
    return _request('DELETE', path, screen: screen, token: token);
  }

  // Sends request to server based on user action, applies timeout, and converts failures into ApiExceptions
  Future<dynamic> _request(String method, String path, {required String screen, Object? body, required TokenType token})
    async {
    final url = Uri.parse('$apiBaseUrl$path');
    final http.Response res;
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final headers = <String, String>{};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    // Adds the token the endpoint, if tablet has one
    final String? bearer = switch (token) {
      TokenType.none => null,
      TokenType.device => await _tokens.readDeviceToken(),
      TokenType.session => await _tokens.readSessionToken(),
    };
    if (bearer != null) {
      headers['Authorization'] = 'Bearer $bearer';
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
    // Any error reply becomes an ApiException, with the server's sentence when it sent one
    if (res.statusCode >= 400) {
      throw _errorFrom(res, screen);
    }
    // Returns null when body is empty
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

  // Builds the ApiException for an error reply, using the server's sentence and code when it sent them
  ApiException _errorFrom(http.Response res, String screen) {
    String message = res.statusCode >= 500
        ? 'There is an issue with the server (error ${res.statusCode}).'
        : 'The request was not accepted (error ${res.statusCode}).';
    String? code;

    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['error'] is String) {
        message = data['error'];
        if (data['code'] is String) {
          code = data['code'];
        }
      }
    } on FormatException {
      // Blank or non-JSON body, so the backup sentence stays
    }
    return ApiException(message, screen: screen, statusCode: res.statusCode, code: code);
  }
}
