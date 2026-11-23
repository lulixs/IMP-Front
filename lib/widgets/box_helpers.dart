import 'package:flutter/services.dart';

/// The shelf letter's typing rules: letters only, at most 3, turned into capitals.
/// (box_page.dart has its own private copy of these. It can switch to this one whenever convenient.)
final shelfLetterRules = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
  LengthLimitingTextInputFormatter(3),
  _UpperCase(),
];

/// Turns typed shelf letters into capitals as they are typed.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// A date as MM/DD/YY in the tablet's time zone, like the wireframes (01/14/26).
String formatDate(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}/${two(local.day)}/${two(local.year % 100)}';
}
