/// At least one character before the @, then at least one between the @ and a dot,
/// then at least one after the dot. One @ only, and no spaces.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Form validator for email fields. Returns the error to show, or null if the email is valid.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter an email';
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email';
  return null;
}
