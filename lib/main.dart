import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'api/api_scope.dart';
import 'api/auth_api.dart';
import 'api/token_store.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'screens/login/employee_login_page.dart';
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
      // Every screen can reach the shared ApiClient, for helpers like openBox
      builder: (context, child) => ApiScope(api: _api, child: child!),
      routes: {AppShell.switchUserRoute: (_) => _employeeSignIn()},
      home: switch (widget.start) {
        null => _startPage(),
        StartScreen.setup => _firstSetup(),
        StartScreen.login => _signBackIn(),
      },
    );
  }

  /// Decides the start screen from the saved tokens, with a spinner meanwhile, then opens it.
  Widget _startPage() => StartPage(decide: () => decideStart(_tokens, _auth), onDecided: _open);

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
      // The device token is gone, so start-up asks the server whether the store still exists: tablet setup if
      // it does, first-time setup if the database was wiped.
      case 'deviceNotSetUp' || 'deviceRemoved':
        openFresh(_startPage());
    }
  }

  /// First-time setup. Confirming saves the store on the server, and AuthApi.setUp saves both tokens and the
  /// employee, so a restart opens the dashboard.
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
          _openDashboard(Session(employeeId: result.employee.id, employeeName: result.employee.name, auth: _auth));
          return null; // it worked, return no error message
        } on ApiException catch (e) {
          return e.message; // did not work, return error message
        }
      },
    );
  }

  /// Setting up a tablet the store doesn't know yet, then employee sign-in.
  Widget _tabletSetup() {
    return MasterLoginPage(
      mode: MasterLoginMode.newTablet,
      onSignIn: (email, password, tabletName) async {
        try {
          await _auth.addTablet(tabletName!, email, password);
          openFresh(_employeeSignIn());
          return null; // success
        } on ApiException catch (e) {
          return e.message;
        }
      },
    );
  }

  /// Signing the tablet back in after its device token expired, then employee sign-in.
  Widget _signBackIn() {
    return MasterLoginPage(
      mode: MasterLoginMode.signIn,
      onSignIn: (email, password, _) async {
        try {
          await _auth.renewTablet(email, password);
          openFresh(_employeeSignIn());
          return null; // success
        } on ApiException catch (e) {
          return e.message;
        }
      },
    );
  }

  /// Employee sign-in on its own: the PIN screen, with no Back button. Also where Switch user lands.
  Widget _employeeSignIn() {
    return EmployeeLoginPage(
      loadEmployees: _auth.activeEmployees,
      showBack: false,
      onSignIn: (employeeId, pin) async {
        try {
          final result = await _auth.signIn(employeeId, pin);
          _openDashboard(Session(employeeId: result.employee.id, employeeName: result.employee.name, auth: _auth));
          return null;
        } on ApiException catch (e) {
          return e.message;
        }
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
    _openDashboard(Session(employeeId: employee.id, employeeName: employee.name, auth: _auth));
    try {
      await _auth.masterModeOff();
    } on ApiException {
      // Master mode is already off in the app, and the server can't be reached to agree. If the session ended,
      // ApiClient has opened employee sign-in.
    }
  }
}
