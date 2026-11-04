import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_page.dart';
import 'screens/login/login_flow.dart';
import 'screens/setup/first_setup_flow.dart';
import 'theme.dart';

void main() => runApp(const ImpApp());

/// The screen the app opens on. Only the debug entry points in lib/dev*.dart change it.
enum StartScreen { setup, login, dashboard }

class ImpApp extends StatelessWidget {
  final StartScreen start;

  const ImpApp({super.key, this.start = StartScreen.setup});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMP',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: switch (start) {
        StartScreen.setup => _setup(),
        StartScreen.login => _login(),
        StartScreen.dashboard => const DashboardPage(),
      },
    );
  }

  Widget _setup() {
    // Builder gives a context below MaterialApp, which Navigator needs.
    return Builder(
      builder: (context) => FirstSetupFlow(
        // Temporary: the setup data is not saved anywhere yet, since there is no
        // backend call. Finishing setup just opens the dashboard.
        onFinished: (data) => _openDashboard(context),
      ),
    );
  }

  Widget _login() {
    return Builder(
      // Temporary: nothing is checked and the employee is not remembered yet.
      builder: (context) => LoginFlow(onFinished: (employeeName) => _openDashboard(context)),
    );
  }

  /// Opens the dashboard and clears everything behind it, so the back button
  /// can't return to setup or sign-in.
  void _openDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (_) => false,
    );
  }
}
