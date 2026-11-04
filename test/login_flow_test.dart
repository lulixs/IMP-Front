import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/screens/login/login_flow.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  final fields = find.byType(TextFormField);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> showFlow(WidgetTester tester, ValueChanged<String> onFinished) {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: LoginFlow(onFinished: onFinished),
      ),
    );
  }

  Future<void> signInMaster(WidgetTester tester) async {
    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'x');
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tap(tester, find.text(digit));
    }
  }

  testWidgets('Blank email or password stays on the Master screen', (tester) async {
    await showFlow(tester, (_) {});

    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.text('Enter an email'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
    expect(find.byType(EmployeeLoginPage), findsNothing);
  });

  testWidgets('An email without an @ and a dot stays on the Master screen', (tester) async {
    await showFlow(tester, (_) {});

    await tester.enterText(fields.at(0), 'manager@example');
    await tester.enterText(fields.at(1), 'x');
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.byType(EmployeeLoginPage), findsNothing);
  });

  testWidgets('Any valid email and password, then any 6-digit PIN, signs in Dan Finkle', (tester) async {
    String? signedIn;
    await showFlow(tester, (name) => signedIn = name);

    await signInMaster(tester);
    expect(find.byType(EmployeeLoginPage), findsOneWidget);
    expect(find.text('Dan Finkle'), findsOneWidget);

    await enterPin(tester, '12345');
    expect(signedIn, isNull, reason: 'the 6th digit signs in, not the 5th');

    await enterPin(tester, '9');
    expect(signedIn, 'Dan Finkle');
  });

  testWidgets('Delete removes the last digit', (tester) async {
    String? signedIn;
    await showFlow(tester, (name) => signedIn = name);
    await signInMaster(tester);

    await enterPin(tester, '12345');
    await tap(tester, find.bySemanticsLabel('Delete'));
    await enterPin(tester, '6');
    expect(signedIn, isNull, reason: 'only 5 digits after the delete');

    await enterPin(tester, '7');
    expect(signedIn, 'Dan Finkle');
  });

  testWidgets('Back returns to the Master screen with the email still filled in', (tester) async {
    await showFlow(tester, (_) {});
    await signInMaster(tester);

    await tap(tester, find.text('Back'));

    expect(find.byType(MasterLoginPage), findsOneWidget);
    expect(find.text('store@example.org'), findsOneWidget);
  });
}
