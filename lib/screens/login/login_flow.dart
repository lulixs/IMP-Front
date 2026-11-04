import 'package:flutter/material.dart';

import 'employee_login_page.dart';
import 'master_login_page.dart';

/// Sign-in: the Master account signs the tablet in, then an employee signs in
/// with their PIN. The employee screen opens on top of the Master one, so Back
/// returns to it.
class LoginFlow extends StatelessWidget {
  /// Called with the employee's name once they have entered their PIN.
  final ValueChanged<String> onFinished;

  const LoginFlow({super.key, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    return MasterLoginPage(
      onSignIn: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EmployeeLoginPage(onSignIn: onFinished)),
      ),
    );
  }
}
