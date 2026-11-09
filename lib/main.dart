import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'screens/login/login_flow.dart';
import 'screens/setup/first_setup_flow.dart';
import 'theme.dart';

void main() => runApp(const ImpApp());

/// The screen the app opens on. Only the debug entry points in lib/dev*.dart change it.
enum StartScreen { setup, login, dashboard }

class ImpApp extends StatelessWidget {
  final StartScreen start;

  /// Passed to the pages that load data. Tests give a fake one so nothing reaches a real server.
  final ApiClient? api;

  const ImpApp({super.key, this.start = StartScreen.setup, this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMP',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: switch (start) {
        StartScreen.setup => _setup(),
        StartScreen.login => _login(),
        StartScreen.dashboard => DashboardPage(api: api),
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
      // Temporary: sign-in uses stand-in checks (see LoginFlow) and the employee is not remembered yet.
      builder: (context) => LoginFlow(onFinished: (employeeName) => _openDashboard(context)),
    );
  }

  /// Opens the dashboard and clears everything behind it, so the back button
  /// can't return to setup or sign-in.
  void _openDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => DashboardPage(api: api)),
      (_) => false,
    );
  }
}
