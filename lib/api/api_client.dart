import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '.../config.dart';
import 'api_exception.dart';


class ApiClient{
    final http.Client _http;

    ApiClient({http.Client? client}) : _http = client ?? http.Client();
}