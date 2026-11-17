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

  // Every request the fake server got, as "METHOD path token"
  late List<String> requests;
  setUp(() => requests = []);

  // A fake server that writes down each request and answers by path. Anything not listed gets the dashboard.
  MockClient server(Map<String, http.Response Function()> replies) {
    return MockClient((request) async {
      requests.add('${request.method} ${request.url.path} ${request.headers['authorization']}');
      final reply = replies[request.url.path];
      return reply == null ? http.Response(dashboardJson, 200) : reply();
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
      expect(requests, isEmpty);
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

  group('Sign-in error codes', () {
    // The tablet is signed in and the dashboard's request gets this reply.
    Future<void> dashboardGets(WidgetTester tester, http.Response reply) async {
      FlutterSecureStorage.setMockInitialValues({...both});
      await tester.pumpWidget(
        ImpApp(client: server({'/api/dashboard': () => reply, '/api/master-mode': () => http.Response('', 204)})),
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

    testWidgets('deviceNotSetUp opens tablet setup and forgets the device token', (tester) async {
      await dashboardGets(tester, errorCode('deviceNotSetUp'));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), isNull);
    });

    testWidgets('deviceRemoved opens tablet setup and forgets both tokens', (tester) async {
      await dashboardGets(tester, errorCode('deviceRemoved'));

      expect(tester.widget<MasterLoginPage>(find.byType(MasterLoginPage)).mode, MasterLoginMode.newTablet);
      expect(canGoBack(tester), isFalse);
      expect(await storage.readDeviceToken(), isNull);
      expect(await storage.readSessionToken(), isNull);
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
