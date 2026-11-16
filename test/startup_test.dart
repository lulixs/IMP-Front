import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/api/auth_api.dart';
import 'package:imp_app/api/token_store.dart';
import 'package:imp_app/main.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/screens/setup/confirmation_page.dart';
import 'package:imp_app/screens/setup/first_setup_flow.dart';
import 'package:imp_app/startup.dart';

// Start-up routing (lib/startup.dart) and the screens the four sign-in error codes open (lib/main.dart).
void main() {
  // A signed-in tablet. Tests copy it with {...both} into the fake storage, since that changes the map it is given.
  const both = {
    'deviceToken': 'device-abc',
    'sessionToken': 'session-xyz',
    'employeeId': '4',
    'employeeName': 'Grace Kim',
  };
  const dashboardJson = '{"alertThresholdDays": 180, "categories": []}';
  const employeesJson = '{"employees": [{"id": 4, "name": "Grace Kim"}]}';

  // Every request the fake server got, as "METHOD path token"
  late List<String> requests;
  setUp(() => requests = []);

  // A fake server that writes down each request and answers by path. The employee list has Grace Kim, and
  // anything else not listed gets the dashboard.
  MockClient server(Map<String, http.Response Function()> replies) {
    return MockClient((request) async {
      requests.add('${request.method} ${request.url.path} ${request.headers['authorization']}');
      final reply = replies[request.url.path];
      if (reply != null) return reply();
      if (request.url.path == '/api/employees/active') return http.Response(employeesJson, 200);
      return http.Response(dashboardJson, 200);
    });
  }

  http.Response ok(String body) => http.Response(body, 200);
  http.Response errorCode(String code) => http.Response('{"error": "A sentence.", "code": "$code"}', 401);

  final storage = TokenStore();

  group('decideStart', () {
    Future<Start> decide(Map<String, String> saved, {bool isSetUp = false}) {
      FlutterSecureStorage.setMockInitialValues({...saved});
      final client = server({'/api/setup/status': () => ok('{"isSetUp": $isSetUp}')});
      return decideStart(TokenStore(), AuthApi(ApiClient(client: client)));
    }

    test('No tokens and the store is not set up: first-time setup', () async {
      expect(await decide({}), Start.firstSetup);
      expect(requests, ['GET /api/setup/status null']);
    });

    test('No tokens and the store is set up: tablet setup', () async {
      expect(await decide({}, isSetUp: true), Start.tabletSetup);
    });

    test('Only a device token: employee sign-in, without asking the server', () async {
      expect(await decide({'deviceToken': 'device-abc'}), Start.employeeSignIn);
      expect(requests, isEmpty);
    });

    test('Both tokens: the dashboard, without asking the server', () async {
      expect(await decide(both), Start.dashboard);
      expect(requests, isEmpty);
    });

    test('A session token without a device token is treated as a new tablet', () async {
      expect(await decide({'sessionToken': 'session-xyz'}, isSetUp: true), Start.tabletSetup);
    });

    test('A new tablet that cannot reach the server throws, so the start page can show why', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = MockClient((request) async => throw http.ClientException('No connection'));

      await expectLater(decideStart(TokenStore(), AuthApi(ApiClient(client: client))), throwsA(isA<ApiException>()));
    });
  });

  group('Start-up', () {
    // Pumps the app with these tokens saved and this fake server, and waits for start-up to finish.
    Future<void> start(WidgetTester tester, Map<String, String> saved, MockClient client) async {
      FlutterSecureStorage.setMockInitialValues({...saved});
      await tester.pumpWidget(ImpApp(client: client));
      await tester.pumpAndSettle();
    }

    bool canGoBack(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator)).canPop();

    testWidgets('Shows a spinner while it decides', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(ImpApp(client: server({'/api/setup/status': () => ok('{"isSetUp": false}')})));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('A new tablet in a new store opens first-time setup', (tester) async {
      await start(tester, {}, server({'/api/setup/status': () => ok('{"isSetUp": false}')}));

      expect(find.byType(FirstSetupFlow), findsOneWidget);
      expect(canGoBack(tester), isFalse);
    });

    testWidgets('A new tablet in a store that is set up opens tablet setup', (tester) async {
      await start(tester, {}, server({'/api/setup/status': () => ok('{"isSetUp": true}')}));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
      expect(canGoBack(tester), isFalse);
    });

    testWidgets('A set-up tablet with nobody signed in opens employee sign-in, with no Back button', (tester) async {
      await start(tester, {'deviceToken': 'device-abc'}, server({}));

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(canGoBack(tester), isFalse);
      expect(requests, [
        'GET /api/employees/active Bearer device-abc',
      ], reason: 'only the names, with the device token');
      expect(find.text('Grace Kim'), findsOneWidget);
    });

    testWidgets('A signed-in tablet opens the dashboard as the saved employee, with Master mode off', (tester) async {
      await start(tester, both, server({'/api/master-mode': () => http.Response('', 204)}));

      final session = tester.widget<DashboardPage>(find.byType(DashboardPage)).session;
      expect(session.employeeName, 'Grace Kim');
      expect(session.masterMode, isFalse);
      expect(canGoBack(tester), isFalse);
    });

    testWidgets('The dashboard tells the server Master mode is off, with the session token', (tester) async {
      await start(tester, both, server({'/api/master-mode': () => http.Response('', 204)}));

      expect(requests, contains('DELETE /api/master-mode Bearer session-xyz'));
      expect(requests, contains('GET /api/dashboard Bearer session-xyz'));
    });

    testWidgets('The dashboard still opens while the server has no Master mode endpoint (404)', (tester) async {
      await start(
        tester,
        both,
        server({
          '/api/master-mode': () => http.Response('{"error": "This address doesn\'t exist on the server."}', 404),
        }),
      );

      expect(find.byType(DashboardPage), findsOneWidget);
      expect(await storage.readSessionToken(), 'session-xyz');
    });

    testWidgets('A session token with no saved employee goes to employee sign-in and drops the session', (
      tester,
    ) async {
      await start(tester, {'deviceToken': 'device-abc', 'sessionToken': 'session-xyz'}, server({}));

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(await storage.readSessionToken(), isNull);
      expect(await storage.readDeviceToken(), 'device-abc');
    });

    testWidgets('A new tablet that cannot reach the server says so, and Try again starts over', (tester) async {
      var online = false;
      final client = MockClient((request) async {
        if (!online) throw http.ClientException('No connection');
        return ok('{"isSetUp": false}');
      });
      await start(tester, {}, client);

      expect(find.text("Couldn't start IMP"), findsOneWidget);
      expect(find.text("Can't reach the server. Check the connection and try again."), findsOneWidget);

      online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(FirstSetupFlow), findsOneWidget);
    });

    testWidgets('A tablet with saved tokens starts even when the server is down', (tester) async {
      await start(tester, {
        'deviceToken': 'device-abc',
      }, MockClient((request) async => throw http.ClientException('No connection')));

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
    });
  });

  group('First-time setup', () {
    final fields = find.byType(TextFormField);

    Future<void> tapButton(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    // Fills in every step of first-time setup and confirms.
    Future<void> completeSetup(WidgetTester tester) async {
      await tester.enterText(fields.at(0), 'manager@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.enterText(fields.at(2), 'password123');
      await tapButton(tester, 'Next');
      await tester.enterText(fields.first, 'Front desk tablet');
      await tapButton(tester, 'Next');
      await tester.enterText(fields.at(0), 'Daniel Finkle');
      await tester.enterText(fields.at(1), '012345');
      await tester.enterText(fields.at(2), '012345');
      await tapButton(tester, 'Next');
      await tapButton(tester, 'Confirm');
    }

    testWidgets('Confirming saves the store, and a restart opens the dashboard as the new employee', (tester) async {
      final client = server({
        '/api/setup/status': () => ok('{"isSetUp": false}'),
        '/api/setup': () => http.Response(
          '{"deviceToken": "new-device", "sessionToken": "new-session", '
          '"employee": {"id": 1, "name": "Daniel Finkle"}}',
          201,
        ),
        '/api/master-mode': () => http.Response('', 204),
      });
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(ImpApp(client: client));
      await tester.pumpAndSettle();
      await completeSetup(tester);

      expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).session.employeeName, 'Daniel Finkle');
      expect(await storage.readDeviceToken(), 'new-device');
      expect(await storage.readSessionToken(), 'new-session');

      // A full restart: a new app on the same storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(ImpApp(client: client));
      await tester.pumpAndSettle();

      expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).session.employeeName, 'Daniel Finkle');
    });

    testWidgets('A refused setup shows the server sentence and stays on the confirmation', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        ImpApp(
          client: server({
            '/api/setup/status': () => ok('{"isSetUp": false}'),
            '/api/setup': () =>
                http.Response('{"error": "This store is already set up. Set up this tablet instead."}', 409),
          }),
        ),
      );
      await tester.pumpAndSettle();
      await completeSetup(tester);

      expect(find.text('This store is already set up. Set up this tablet instead.'), findsOneWidget);
      expect(find.byType(ConfirmationPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
      expect(await storage.readDeviceToken(), isNull);
    });
  });

  group('A tablet whose store was wiped (the database was emptied while it still had tokens)', () {
    // What the real server answers once the database is empty: the tablet's rows are gone, so a session token is
    // sessionEnded and a device token is deviceNotSetUp, and the store isn't set up.
    MockClient wipedServer() {
      return server({
        '/api/dashboard': () => errorCode('sessionEnded'),
        '/api/master-mode': () => errorCode('sessionEnded'),
        '/api/employees/active': () => errorCode('deviceNotSetUp'),
        '/api/setup/status': () => ok('{"isSetUp": false}'),
      });
    }

    testWidgets('Ends on first-time setup, with both tokens and the employee forgotten', (tester) async {
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(ImpApp(client: wipedServer()));
      await tester.pumpAndSettle();

      expect(find.byType(FirstSetupFlow), findsOneWidget);
      expect(find.byType(MasterLoginPage), findsNothing, reason: 'tablet setup would only say the store is not set up');
      expect(await storage.readDeviceToken(), isNull);
      expect(await storage.readSessionToken(), isNull);
      expect(await storage.readEmployee(), isNull);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('Goes through employee sign-in on the way, as each token is found to be gone', (tester) async {
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(ImpApp(client: wipedServer()));
      await tester.pumpAndSettle();

      // Start-up's Master mode call finds the session gone, then the name list finds the device gone, then
      // start-up asks, with no token, whether the store exists.
      expect(requests.first, 'DELETE /api/master-mode Bearer session-xyz');
      expect(
        requests,
        containsAllInOrder(['GET /api/employees/active Bearer device-abc', 'GET /api/setup/status null']),
      );
    });

    testWidgets('A tablet with only its device token also ends on first-time setup', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'deviceToken': 'device-abc'});
      await tester.pumpWidget(ImpApp(client: wipedServer()));
      await tester.pumpAndSettle();

      expect(find.byType(FirstSetupFlow), findsOneWidget);
      expect(await storage.readDeviceToken(), isNull);
    });
  });

  group('A reply in an unexpected shape', () {
    testWidgets('Setup status shows why on the start page instead of spinning forever', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(ImpApp(client: server({'/api/setup/status': () => ok('{"something": "else"}')})));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Couldn't start IMP"), findsOneWidget);
      expect(find.text('The server sent back something IMP could not read.'), findsOneWidget);
    });

    testWidgets('The employee list shows why on employee sign-in instead of spinning forever', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'deviceToken': 'device-abc'});
      await tester.pumpWidget(ImpApp(client: server({'/api/employees/active': () => ok('{"names": ["Grace Kim"]}')})));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('The list of names could not be read.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Sign-in error codes', () {
    // The tablet is signed in and the dashboard's request gets this reply. When start-up asks again, the server
    // says whether the store is still set up.
    Future<void> dashboardGets(WidgetTester tester, http.Response reply, {bool storeExists = true}) async {
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(
        ImpApp(
          client: server({
            '/api/dashboard': () => reply,
            '/api/master-mode': () => http.Response('', 204),
            '/api/setup/status': () => ok('{"isSetUp": $storeExists}'),
          }),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool canGoBack(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator)).canPop();

    testWidgets('sessionEnded opens employee sign-in and forgets the session', (tester) async {
      await dashboardGets(tester, errorCode('sessionEnded'));

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(find.byType(DashboardPage, skipOffstage: false), findsNothing);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readSessionToken(), isNull);
      expect(await storage.readEmployee(), isNull);
      expect(await storage.readDeviceToken(), 'device-abc');
    });

    testWidgets('deviceExpired opens the Master sign-in to sign the tablet back in, keeping its tokens', (
      tester,
    ) async {
      await dashboardGets(tester, errorCode('deviceExpired'));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.signIn);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), 'device-abc');
    });

    testWidgets('deviceNotSetUp in a store that still exists opens tablet setup and forgets the device token', (
      tester,
    ) async {
      await dashboardGets(tester, errorCode('deviceNotSetUp'));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), isNull);
    });

    testWidgets('deviceNotSetUp after the store was wiped opens first-time setup', (tester) async {
      await dashboardGets(tester, errorCode('deviceNotSetUp'), storeExists: false);

      expect(find.byType(FirstSetupFlow), findsOneWidget);
      expect(find.byType(MasterLoginPage), findsNothing);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), isNull);
    });

    testWidgets('deviceRemoved in a store that still exists opens tablet setup and forgets both tokens', (
      tester,
    ) async {
      await dashboardGets(tester, errorCode('deviceRemoved'));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), isNull);
      expect(await storage.readSessionToken(), isNull);
    });

    testWidgets('deviceRemoved after the store was wiped opens first-time setup', (tester) async {
      await dashboardGets(tester, errorCode('deviceRemoved'), storeExists: false);

      expect(find.byType(FirstSetupFlow), findsOneWidget);
      expect(await storage.readDeviceToken(), isNull);
      expect(await storage.readSessionToken(), isNull);
    });

    testWidgets('The two device codes ask the server again, with no token, whether the store exists', (tester) async {
      await dashboardGets(tester, errorCode('deviceNotSetUp'));

      expect(requests, contains('GET /api/setup/status null'));
    });

    testWidgets('If the server can\'t say whether the store exists, the start page says so and Try again recovers', (
      tester,
    ) async {
      // The connection is down the first time start-up asks, and back the second time.
      var statusAsks = 0;
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(
        ImpApp(
          client: MockClient((request) async {
            if (request.url.path == '/api/setup/status') {
              if (++statusAsks == 1) throw http.ClientException('No connection');
              return ok('{"isSetUp": true}');
            }
            if (request.url.path == '/api/dashboard') return errorCode('deviceNotSetUp');
            return http.Response('', 204);
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't start IMP"), findsOneWidget);
      expect(find.text("Can't reach the server. Check the connection and try again."), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
    });

    testWidgets('An error with no code stays on the dashboard with its message and Try again', (tester) async {
      await dashboardGets(tester, http.Response('{"error": "Something went wrong. Please try again later."}', 500));

      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(await storage.readSessionToken(), 'session-xyz');
    });

    testWidgets('A session that ends at start-up, on the Master mode call, also opens employee sign-in', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(ImpApp(client: server({'/api/master-mode': () => errorCode('sessionEnded')})));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeLoginPage), findsOneWidget);
      expect(await storage.readSessionToken(), isNull);
    });
  });
}
