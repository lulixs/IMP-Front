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

  // Sends GET request for given path
  // Throws ApiExceptions if anything goes wrong
  Future<dynamic> get(String path, {required String screen}) async {
    final url = Uri.parse('$apiBaseUrl$path');
    final http.Response res;

    try {
      res = await _http.get(url).timeout(apiTimeout);
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
