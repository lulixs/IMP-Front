import 'package:flutter/foundation.dart';

/// The current sign-in: which employee is signed in and whether Master mode is on.
/// One Session is made when someone signs in, then passed to every AppShell, so it
/// lasts while they move between pages.
class Session extends ChangeNotifier {
  /// The employee who signed in with their PIN.
  final String employeeName;

  bool _masterMode;

  Session({required this.employeeName, bool masterMode = false}) : _masterMode = masterMode;

  /// Whether Master mode is on. The Master-only pages are locked while it is off.
  bool get masterMode => _masterMode;

  /// Turns Master mode on or off, and tells every AppShell listening so it can redraw.
  set masterMode(bool value) {
    if (value == _masterMode) return;
    _masterMode = value;
    notifyListeners();
  }
}
