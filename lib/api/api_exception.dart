// Exception thrown when request to backend fails
// Carries exception message, screen it occurred on, the status code, and the server's error code
class ApiException implements Exception {
  final String message;
  final String screen;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {required this.screen, this.statusCode, this.code});

  // Replaces Dart's default exception with fixed exception message
  @override
  String toString() {
    return '[$screen] $message';
  }
}
