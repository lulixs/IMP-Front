import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/token_store.dart';
import 'package:imp_app/main.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/screens/setup/first_setup_flow.dart';

/// A fake IMP-Back that remembers, like the DEVICE row, who is signed in on this tablet and whether Master mode
/// is on, so tests can check the app against it. The Master password is master123, Daniel's PIN is 111111, and
/// Grace's is 444444.
class FakeServer {
  bool isSetUp;
  int? activeEmployeeId;
  bool isElevated = false;
  final requests = <String>[];

  static const _names = {1: 'Daniel Finkle', 4: 'Grace Kim'};
  static const _pins = {1: '111111', 4: '444444'};

  FakeServer({this.isSetUp = true});

  late final client = MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
    final masterOk = body['email'] == 'manager@example.com' && body['password'] == 'master123';
    http.Response json(Object value, [int status = 200]) => http.Response(jsonEncode(value), status);
    final wrongMaster = json({'error': 'Incorrect email or password. Try again.'}, 401);

    switch ('${request.method} ${request.url.path}') {
      case 'GET /api/setup/status':
        return json({'isSetUp': isSetUp});
      case 'POST /api/setup':
        isSetUp = true;
        activeEmployeeId = 1;
        return json({
          'deviceToken': 'device-new',
          'sessionToken': 'session-1',
          'employee': {'id': 1, 'name': body['employeeName']},
        }, 201);
      case 'POST /api/devices':
        if (!masterOk) return wrongMaster;
        return json({
          'deviceToken': 'device-new',
          'device': {'id': 2, 'name': body['tabletName']},
        }, 201);
      case 'POST /api/devices/renew':
        if (!masterOk) return wrongMaster;
        return json({'deviceToken': 'device-renewed'});
      case 'GET /api/employees/active':
        return json({
          'employees': [
            for (final entry in _names.entries) {'id': entry.key, 'name': entry.value},
          ],
        });
      case 'POST /api/sessions':
        final id = body['employeeId'] as int;
        if (_pins[id] != body['pin']) return json({'error': 'Incorrect PIN. Try again.'}, 401);
        activeEmployeeId = id;
        isElevated = false;
        return json({
          'sessionToken': 'session-$id',
          'employee': {'id': id, 'name': _names[id]},
        });
      case 'DELETE /api/sessions/current':
        activeEmployeeId = null;
        isElevated = false;
        return http.Response('', 204);
      case 'POST /api/master-mode':
        if (!masterOk) return wrongMaster;
        isElevated = true;
        return http.Response('', 204);
      case 'DELETE /api/master-mode':
        isElevated = false;
        return http.Response('', 204);
      default:
        return json({'alertThresholdDays': 180, 'categories': []});
    }
  });
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final fields = find.byType(TextFormField);
  final tokens = TokenStore();

  void setSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) => tap(tester, find.text(label));

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tapText(tester, digit);
    }
  }

  /// Starts the app on [server], with [saved] in the tablet's storage, and waits for start-up. [start] skips
  /// start-up routing, like the debug entry points.
  Future<void> startApp(
    WidgetTester tester,
    FakeServer server, {
    Map<String, String> saved = const {},
    StartScreen? start,
  }) async {
    setSize(tester);
    FlutterSecureStorage.setMockInitialValues({...saved});
    await tester.pumpWidget(ImpApp(start: start, client: server.client));
    await tester.pumpAndSettle();
  }

  /// A full restart: a new app on the same storage.
  Future<void> restart(WidgetTester tester, FakeServer server) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ImpApp(client: server.client));
    await tester.pumpAndSettle();
  }

  /// Fills in the Master email and password (and the tablet name, if the screen asks) and taps the button.
  Future<void> signInMaster(WidgetTester tester, {String password = 'master123', String? tabletName}) async {
    final emailAt = tabletName == null ? 0 : 1;
    if (tabletName != null) await tester.enterText(fields.at(0), tabletName);
    await tester.enterText(fields.at(emailAt), 'manager@example.com');
    await tester.enterText(fields.at(emailAt + 1), password);
    await tap(tester, find.descendant(of: find.byType(MasterLoginPage), matching: find.byType(FilledButton)));
  }

  String? signedInName(WidgetTester tester) {
    final dashboard = find.byType(DashboardPage);
    return dashboard.evaluate().isEmpty ? null : tester.widget<DashboardPage>(dashboard).session.employeeName;
  }

  bool canGoBack(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator)).canPop();

  const signedIn = {
    'deviceToken': 'device-abc',
    'sessionToken': 'session-1',
    'employeeId': '1',
    'employeeName': 'Daniel Finkle',
  };

  group('First-time setup', () {
    testWidgets('Confirming setup opens the dashboard, and back cannot return to setup', (tester) async {
      final server = FakeServer(isSetUp: false);
      await startApp(tester, server);

      await tester.enterText(fields.at(0), 'manager@example.com');
      await tester.enterText(fields.at(1), 'master123');
      await tester.enterText(fields.at(2), 'master123');
      await tapText(tester, 'Next');
      await tester.enterText(fields.first, 'Front desk');
      await tapText(tester, 'Next');
      await tester.enterText(fields.at(0), 'Mabel');
      await tester.enterText(fields.at(1), '123456');
      await tester.enterText(fields.at(2), '123456');
      await tapText(tester, 'Next');
      await tapText(tester, 'Confirm');

      expect(signedInName(tester), 'Mabel', reason: 'the employee made during setup is the one signed in');
      expect(find.byType(FirstSetupFlow), findsNothing);
      expect(canGoBack(tester), isFalse);
    });
  });

  group('Tablet setup', () {
    testWidgets('Sets up the tablet on the server, then opens employee sign-in with the real names', (tester) async {
      final server = FakeServer();
      await startApp(tester, server);
      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);

      await signInMaster(tester, tabletName: 'Stockroom tablet');

      expect(server.requests, contains('POST /api/devices'));
      expect(await tokens.readDeviceToken(), 'device-new');
      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.text('Daniel Finkle'), findsOneWidget);
      expect(canGoBack(tester), isFalse);
    });

    testWidgets('A wrong Master password shows the server\'s sentence and saves nothing', (tester) async {
      final server = FakeServer();
      await startApp(tester, server);

      await signInMaster(tester, tabletName: 'Stockroom tablet', password: 'nope');

      expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
      expect(find.byType(MasterLoginPage), findsOneWidget);
      expect(await tokens.readDeviceToken(), isNull);
    });
  });

  group('Signing back in', () {
    testWidgets('Renews the tablet on the server, then opens employee sign-in', (tester) async {
      final server = FakeServer();
      // The app opens this after a deviceExpired reply. StartScreen.login opens it directly.
      await startApp(tester, server, saved: {'deviceToken': 'device-old'}, start: StartScreen.login);

      await signInMaster(tester);

      expect(server.requests, contains('POST /api/devices/renew'));
      expect(await tokens.readDeviceToken(), 'device-renewed');
      expect(find.byType(EmployeeLoginPage), findsOneWidget);
    });

    testWidgets('A wrong Master password shows the server\'s sentence and keeps the old device token', (tester) async {
      final server = FakeServer();
      await startApp(tester, server, saved: {'deviceToken': 'device-old'}, start: StartScreen.login);

      await signInMaster(tester, password: 'nope');

      expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
      expect(await tokens.readDeviceToken(), 'device-old');
    });
  });

  group('Employee sign-in', () {
    testWidgets('A wrong PIN shows the server\'s sentence, and the right one opens the dashboard', (tester) async {
      final server = FakeServer();
      await startApp(tester, server, saved: {'deviceToken': 'device-abc'});

      await enterPin(tester, '000000');
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(server.activeEmployeeId, isNull);

      await enterPin(tester, '111111');
      expect(signedInName(tester), 'Daniel Finkle');
      expect(server.activeEmployeeId, 1);
      expect(canGoBack(tester), isFalse);
    });

    testWidgets('Signs in whoever is picked, and a restart opens the dashboard as them', (tester) async {
      final server = FakeServer();
      await startApp(tester, server, saved: {'deviceToken': 'device-abc'});

      await tapText(tester, 'Daniel Finkle');
      await tap(tester, find.text('Grace Kim').last);
      await enterPin(tester, '444444');
      expect(signedInName(tester), 'Grace Kim');
      expect(server.activeEmployeeId, 4);

      await restart(tester, server);
      expect(signedInName(tester), 'Grace Kim');
    });
  });

  group('Master mode', () {
    testWidgets('Turns on and off through the server, which agrees with the sidebar each time', (tester) async {
      final server = FakeServer();
      await startApp(tester, server, saved: signedIn);

      await tapText(tester, 'Master off');
      await tapText(tester, 'Turn on');
      await signInMaster(tester, password: 'nope');
      expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
      expect(server.isElevated, isFalse);

      await signInMaster(tester);
      expect(find.text('Master on'), findsOneWidget);
      expect(server.isElevated, isTrue);

      await tapText(tester, 'Master on');
      await tapText(tester, 'Turn off');
      expect(find.text('Master off'), findsOneWidget);
      expect(server.isElevated, isFalse);
    });
  });

  group('Switch user', () {
    testWidgets('Signs out on the server, and the next sign-in is a new session with Master mode off', (tester) async {
      final server = FakeServer()..activeEmployeeId = 1;
      await startApp(tester, server, saved: signedIn);
      await tapText(tester, 'Master off');
      await tapText(tester, 'Turn on');
      await signInMaster(tester);
      final firstSession = tester.widget<DashboardPage>(find.byType(DashboardPage)).session;

      await tapText(tester, 'Switch user');

      expect(server.activeEmployeeId, isNull);
      expect(server.isElevated, isFalse);
      expect(await tokens.readSessionToken(), isNull);
      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(canGoBack(tester), isFalse);

      await tapText(tester, 'Daniel Finkle');
      await tap(tester, find.text('Grace Kim').last);
      await enterPin(tester, '444444');
      final secondSession = tester.widget<DashboardPage>(find.byType(DashboardPage)).session;
      expect(secondSession, isNot(same(firstSession)));
      expect(secondSession.employeeName, 'Grace Kim');
      expect(secondSession.masterMode, isFalse);
      expect(find.text('Master off'), findsOneWidget);
    });

    testWidgets('After Switch user, a restart opens employee sign-in, not the old dashboard', (tester) async {
      final server = FakeServer()..activeEmployeeId = 1;
      await startApp(tester, server, saved: signedIn);

      await tapText(tester, 'Switch user');
      await restart(tester, server);

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
    });
  });
}
