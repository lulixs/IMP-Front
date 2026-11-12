import 'package:flutter/material.dart';

import 'employee_login_page.dart';
import 'master_login_page.dart';

/// Sign-in: the Master account signs the tablet in, then an employee signs in
/// with their PIN. The employee screen opens on top of the Master one, so Back
/// returns to it.
///
/// Temporary: nothing is checked against the backend yet. Any password works
/// except [wrongPassword], and any PIN works except [wrongPin]. Those two always
/// fail, so the error boxes can be seen and tested.
class LoginFlow extends StatelessWidget {
  static const wrongPassword = 'wrong';
  static const wrongPin = '000000';

  /// Called with the employee's name once they have entered their PIN.
  final ValueChanged<String> onFinished;

  const LoginFlow({super.key, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    return MasterLoginPage(
      mode: MasterLoginMode.signIn,
      onSignIn: (email, password, _) => _masterSignIn(context, email, password),
    );
  }

  /// Stand-in for the backend's Master account check. Completes with the error to show, or null
  /// if it passes. Turning Master mode on uses it too. It is async because the real
  /// check will ask the server.
  static Future<String?> checkMaster(String email, String password) async {
    return password == wrongPassword ? 'Incorrect email or password. Try again.' : null;
  }

  /// Stand-in for the backend's PIN check. Completes with the error to show, or null if it passes.
  /// Switch user uses it too. It is async because the real check will ask the server.
  static Future<String?> checkPin(String name, String pin) async {
    return pin == wrongPin ? 'Incorrect PIN for $name. Try again.' : null;
  }

  Future<String?> _masterSignIn(BuildContext context, String email, String password) async {
    final error = await checkMaster(email, password);
    if (error != null) return error;
    if (!context.mounted) return null;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeLoginPage(onSignIn: _employeeSignIn)));
    return null;
  }

  Future<String?> _employeeSignIn(String name, String pin) async {
    final error = await checkPin(name, pin);
    if (error != null) return error;
    onFinished(name);
    return null;
  }
}
