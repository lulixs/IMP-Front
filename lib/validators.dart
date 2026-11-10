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

/// Longest tablet name allowed. Matches DEVICE.device_name, VARCHAR(100) in the ERD.
const maxTabletNameLength = 100;

/// Form validator for tablet name fields, used in first-time setup and when adding a tablet.
/// Returns the error to show, or null if the name is valid. Any characters are allowed,
/// but the name can't be blank or longer than [maxTabletNameLength] once trimmed.
String? validateTabletName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter a tablet name';
  if (name.length > maxTabletNameLength) return 'Use $maxTabletNameLength characters or fewer';
  return null;
}
