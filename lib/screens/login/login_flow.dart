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
    return MasterLoginPage(onSignIn: (email, password) => _masterSignIn(context, email, password));
  }

  String? _masterSignIn(BuildContext context, String email, String password) {
    if (password == wrongPassword) return 'Incorrect email or password. Try again.';
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeLoginPage(onSignIn: _employeeSignIn)));
    return null;
  }

  String? _employeeSignIn(String name, String pin) {
    if (pin == wrongPin) return 'Incorrect PIN for $name. Try again.';
    onFinished(name);
    return null;
  }
}
