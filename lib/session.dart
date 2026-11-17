import 'package:flutter/foundation.dart';

import 'api/api_exception.dart';
import 'api/auth_api.dart';

/// The current sign-in: which employee is signed in and whether Master mode is on.
/// One Session is made when someone signs in, then passed to every AppShell, so it
/// lasts while they move between pages.
class Session extends ChangeNotifier {
  /// The employee who signed in with their PIN.
  final int employeeId;
  final String employeeName;

  /// Master mode is turned on and off through the server, which decides what it unlocks.
  final AuthApi _auth;

  bool _masterMode;

  Session({required this.employeeId, required this.employeeName, required this._auth, this._masterMode = false});

  /// Whether Master mode is on. The Master-only pages are locked while it is off.
  bool get masterMode => _masterMode;

  /// Turns Master mode on or off here only, and tells every AppShell listening so it can redraw.
  /// Use turnOnMasterMode and turnOffMasterMode to change it on the server too.
  set masterMode(bool value) {
    if (value == _masterMode) return;
    _masterMode = value;
    notifyListeners();
  }

  /// Turns Master mode on once the server accepts the Master email and password (POST /api/master-mode).
  /// Completes with null once it is on, or the sentence to show if the server refused.
  Future<String?> turnOnMasterMode(String email, String password) async {
    try {
      await _auth.masterModeOn(email, password);
    } on ApiException catch (e) {
      return e.message;
    }
    masterMode = true;
    return null;
  }

  /// Turns Master mode off on the server (DELETE /api/master-mode), then here. If the server can't do it, this
  /// throws ApiException and Master mode stays on, so the app never shows it off while the server has it on.
  Future<void> turnOffMasterMode() async {
    await _auth.masterModeOff();
    masterMode = false;
  }

  /// Signs the employee out on the server (DELETE /api/sessions/current), and forgets the saved session.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
