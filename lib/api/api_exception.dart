// Exception thrown when request to backend fails
// Carries exception message and screen that had it
class ApiException implements Exception{
    final String message;
    final String screen;
    final int? statusCode; // optional

    ApiException(this.message, {required this.screen, this.statusCode});

// Replaces Dart's default exeption with ours
    @override
    String toString() => '[$screen] $message';
}