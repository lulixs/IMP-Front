import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/main.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/screens/login/login_flow.dart';
import 'package:imp_app/screens/setup/first_setup_flow.dart';

void main() {
  final fields = find.byType(TextFormField);

  // The dashboard loads data when it opens, so give it a fake server instead of a real one.
  final api = ApiClient(
    client: MockClient((request) async => http.Response('{"alertThresholdDays": 180, "categories": []}', 200)),
  );

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Confirming setup opens the dashboard, and back cannot return to setup', (tester) async {
    await tester.pumpWidget(ImpApp(api: api));

    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.enterText(fields.at(2), 'secret123');
    await tapButton(tester, 'Next');
    await tester.enterText(fields.first, 'Front desk');
    await tapButton(tester, 'Next');
    await tester.enterText(fields.at(0), 'Mabel');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Confirm');

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).session.employeeName, 'Mabel',
        reason: 'the employee made during setup is the one signed in');
    expect(find.byType(FirstSetupFlow), findsNothing);

    // Nothing is left behind the dashboard, so the back button has nowhere to go.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('StartScreen.dashboard opens the dashboard directly', (tester) async {
    await tester.pumpWidget(ImpApp(start: StartScreen.dashboard, api: api));

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).session.employeeName, 'Dan Finkle',
        reason: 'the stub employee');
    expect(find.byType(FirstSetupFlow), findsNothing);
  });

  testWidgets('Signing in from StartScreen.login opens the dashboard, and back cannot return', (tester) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ImpApp(start: StartScreen.login, api: api));

    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    for (final digit in '123456'.split('')) {
      await tapButton(tester, digit);
    }

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).session.employeeName, 'Dan Finkle',
        reason: 'the employee who entered their PIN');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('Switch user throws the session away, and the next PIN sign-in starts a new one', (tester) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ImpApp(start: StartScreen.login, api: api));
    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    for (final digit in '123456'.split('')) {
      await tapButton(tester, digit);
    }
    final firstSession = tester.widget<DashboardPage>(find.byType(DashboardPage)).session;

    // Turn Master mode on, then switch user.
    await tapButton(tester, 'Master off');
    await tapButton(tester, 'Turn on');
    expect(firstSession.masterMode, isTrue);
    await tapButton(tester, 'Switch user');

    // Straight to the PIN screen, with nothing behind it and no Back button.
    expect(find.byType(EmployeeLoginPage), findsOneWidget);
    expect(find.byType(DashboardPage, skipOffstage: false), findsNothing);
    expect(find.text('Back'), findsNothing);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);

    // A wrong PIN still shows the error here.
    for (final digit in LoginFlow.wrongPin.split('')) {
      await tapButton(tester, digit);
    }
    expect(find.text('Incorrect PIN for Dan Finkle. Try again.'), findsOneWidget);

    // The right PIN opens the dashboard with a brand new session, so Master mode is off again.
    for (final digit in '123456'.split('')) {
      await tapButton(tester, digit);
    }
    final secondSession = tester.widget<DashboardPage>(find.byType(DashboardPage)).session;
    expect(secondSession, isNot(same(firstSession)));
    expect(secondSession.employeeName, 'Dan Finkle');
    expect(secondSession.masterMode, isFalse);
    expect(find.text('Master off'), findsOneWidget);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}
