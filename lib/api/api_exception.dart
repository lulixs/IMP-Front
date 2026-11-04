// Exception thrown when request to backend fails
// Carries exception message, screen it occurred on, and the status code (if applicable)
class ApiException implements Exception {
  final String message;
  final String screen;
  final int? statusCode;

  ApiException(this.message, {required this.screen, this.statusCode});

  // Replaces Dart's default exception with fixed exception message
  @override
  String toString() {
    return '[$screen] $message';
  }
}
