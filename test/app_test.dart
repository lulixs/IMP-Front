import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/main.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/screens/setup/first_setup_flow.dart';

void main() {
  final fields = find.byType(TextFormField);

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Confirming setup opens the dashboard, and back cannot return to setup', (tester) async {
    await tester.pumpWidget(const ImpApp());

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
    expect(find.byType(FirstSetupFlow), findsNothing);

    // Nothing is left behind the dashboard, so the back button has nowhere to go.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('StartScreen.dashboard opens the dashboard directly', (tester) async {
    await tester.pumpWidget(const ImpApp(start: StartScreen.dashboard));

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(FirstSetupFlow), findsNothing);
  });

  testWidgets('Signing in from StartScreen.login opens the dashboard, and back cannot return', (tester) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpApp(start: StartScreen.login));

    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    for (final digit in '123456'.split('')) {
      await tapButton(tester, digit);
    }

    expect(find.byType(DashboardPage), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });
}
