import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'api/auth_api.dart';
import 'api/token_store.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'screens/login/employee_login_page.dart';
import 'screens/login/login_flow.dart';
import 'screens/login/master_login_page.dart';
import 'screens/setup/first_setup_flow.dart';
import 'session.dart';
import 'startup.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

void main() => runApp(const ImpApp());

/// Debug only: skips start-up routing and opens this screen. Only the debug entry points in lib/dev*.dart set it.
enum StartScreen { setup, login }

class ImpApp extends StatefulWidget {
  /// Null runs start-up routing (see startup.dart), which picks the screen from the saved tokens.
  final StartScreen? start;

  /// The HTTP client every request goes through. Tests give a fake one so nothing reaches a real server.
  final http.Client? client;

  const ImpApp({super.key, this.start, this.client});

  @override
  State<ImpApp> createState() => _ImpAppState();
}

class _ImpAppState extends State<ImpApp> {
  final _tokens = TokenStore();

  /// The one ApiClient the whole app shares, so every request reports token problems to the same place.
  late final _api = ApiClient(client: widget.client, tokens: _tokens, onTokenProblem: _onTokenProblem);
  late final _auth = AuthApi(_api, tokens: _tokens);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMP',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routes: {AppShell.switchUserRoute: (_) => _employeeSignIn()},
      home: switch (widget.start) {
        null => StartPage(decide: () => decideStart(_tokens, _auth), onDecided: _open),
        StartScreen.setup => _firstSetup(),
        StartScreen.login => _signBackIn(),
      },
    );
  }

  /// Opens the screen decideStart picked.
  void _open(Start start) {
    switch (start) {
      case Start.firstSetup:
        openFresh(_firstSetup());
      case Start.tabletSetup:
        openFresh(_tabletSetup());
      case Start.employeeSignIn:
        openFresh(_employeeSignIn());
      case Start.dashboard:
        _openSavedDashboard();
    }
  }

  /// ApiClient calls this after clearing the tokens for one of the four codes in IMP-Back docs/api/README.md.
  void _onTokenProblem(String code) {
    switch (code) {
      case 'sessionEnded':
        openFresh(_employeeSignIn());
      case 'deviceExpired':
        openFresh(_signBackIn());
      case 'deviceNotSetUp' || 'deviceRemoved':
        openFresh(_tabletSetup());
    }
  }

  /// First-time setup. Confirming saves the store on the server, and AuthApi.setUp saves both tokens and the
  /// employee, so a restart opens the dashboard.
  /// Temporary: a failed setup only shows the server's sentence in a bar at the bottom. Connect the sign-in
  /// screens shows it on the confirmation screen instead.
  Widget _firstSetup() {
    return FirstSetupFlow(
      onFinished: (data) async {
        try {
          final result = await _auth.setUp(
            data.masterEmail,
            data.masterPassword,
            data.tabletName,
            data.employeeName,
            data.employeePin,
          );
          _openDashboard(Session(employeeName: result.employee.name));
        } on ApiException catch (e) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
    );
  }

  /// Setting up a tablet the store doesn't know yet, then employee sign-in.
  /// Temporary: uses LoginFlow's stand-in check until Connect the sign-in screens calls POST /api/devices.
  Widget _tabletSetup() {
    return MasterLoginPage(
      mode: MasterLoginMode.newTablet,
      onSignIn: (email, password, _) async {
        final error = await LoginFlow.checkMaster(email, password);
        if (error == null) openFresh(_employeeSignIn());
        return error;
      },
    );
  }

  /// Signing the tablet back in after its device token expired, then employee sign-in.
  /// Temporary: LoginFlow's stand-in checks until Connect the sign-in screens calls POST /api/devices/renew.
  Widget _signBackIn() {
    return LoginFlow(onFinished: (employeeName) => _openDashboard(Session(employeeName: employeeName)));
  }

  /// Employee sign-in on its own: the PIN screen, with no Back button. Also where Switch user lands.
  /// Temporary: stub names and LoginFlow's stand-in check until Connect the sign-in screens calls POST /api/sessions.
  Widget _employeeSignIn() {
    return EmployeeLoginPage(
      showBack: false,
      onSignIn: (name, pin) async {
        final error = await LoginFlow.checkPin(name, pin);
        if (error == null) _openDashboard(Session(employeeName: name));
        return error;
      },
    );
  }

  /// Opens the dashboard for a new sign-in, with nothing behind it.
  void _openDashboard(Session session) {
    openFresh(DashboardPage(api: _api, session: session));
  }

  /// Both tokens are saved: open the dashboard as the saved employee, with Master mode off, and tell the server
  /// so it agrees.
  Future<void> _openSavedDashboard() async {
    final employee = await _tokens.readEmployee();
    // A session token with no saved employee can't fill the sidebar, so sign in again.
    if (employee == null) {
      await _tokens.deleteSessionToken();
      openFresh(_employeeSignIn());
      return;
    }
    _openDashboard(Session(employeeName: employee.name));
    try {
      await _auth.masterModeOff();
    } on ApiException {
      // Master mode is already off in the app. If the session ended, ApiClient has opened employee sign-in.
      // Until the Master mode endpoints are merged into IMP-Back, this call gets a 404.
    }
  }
}
