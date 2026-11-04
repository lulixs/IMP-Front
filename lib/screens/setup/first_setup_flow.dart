import 'package:flutter/material.dart';

import 'confirmation_page.dart';
import 'first_employee_page.dart';
import 'first_setup_data.dart';
import 'master_account_page.dart';
import 'tablet_name_page.dart';

export 'first_setup_data.dart';

/// First-time setup on a new install (D-133): Master account, then tablet name,
/// then first employee, then a confirmation of all three. Each step opens on top
/// of the last, so Back (or the tablet's back button) returns to the previous
/// step with its fields still filled in.
class FirstSetupFlow extends StatelessWidget {
  /// Called once the last step is confirmed, with what every step entered.
  final void Function(FirstSetupData data) onFinished;

  const FirstSetupFlow({super.key, required this.onFinished});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return MasterAccountPage(
      onNext: (email, password) => _open(
        context,
        TabletNamePage(
          onNext: (tabletName) => _open(
            context,
            FirstEmployeePage(
              onNext: (employeeName, pin) {
                final data = FirstSetupData(
                  masterEmail: email,
                  masterPassword: password,
                  tabletName: tabletName,
                  employeeName: employeeName,
                  employeePin: pin,
                );
                _open(context, ConfirmationPage(data: data, onConfirm: () => onFinished(data)));
              },
            ),
          ),
        ),
      ),
    );
  }
}
