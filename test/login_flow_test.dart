import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/screens/login/login_flow.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  final fields = find.byType(TextFormField);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> showPage(WidgetTester tester, Widget page) {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(MaterialApp(theme: buildTheme(), home: page));
  }

  Future<void> showFlow(WidgetTester tester, ValueChanged<String> onFinished) {
    return showPage(tester, LoginFlow(onFinished: onFinished));
  }

  Future<void> signInMaster(WidgetTester tester, {String password = 'x'}) async {
    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), password);
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

  testWidgets('A valid email and password, then a 6-digit PIN, signs in Dan Finkle', (tester) async {
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

  testWidgets('No error box shows before a failed sign-in', (tester) async {
    await showFlow(tester, (_) {});
    expect(find.byType(ErrorBox), findsNothing);

    await signInMaster(tester);
    expect(find.byType(ErrorBox), findsNothing);
  });

  testWidgets('The password "wrong" shows the error box and stays on the Master screen', (tester) async {
    await showFlow(tester, (_) {});

    await signInMaster(tester, password: LoginFlow.wrongPassword);

    expect(find.byType(ErrorBox), findsOneWidget);
    expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
    expect(find.byType(EmployeeLoginPage), findsNothing);

    // A different password gets through, and the error is gone when Back returns here.
    await signInMaster(tester);
    expect(find.byType(EmployeeLoginPage), findsOneWidget);
    await tap(tester, find.text('Back'));
    expect(find.byType(ErrorBox), findsNothing);
  });

  testWidgets('The PIN 000000 shows the error box and clears the PIN for another try', (tester) async {
    String? signedIn;
    await showFlow(tester, (name) => signedIn = name);
    await signInMaster(tester);

    await enterPin(tester, LoginFlow.wrongPin);

    expect(signedIn, isNull);
    expect(find.byType(ErrorBox), findsOneWidget);
    expect(find.text('Incorrect PIN for Dan Finkle. Try again.'), findsOneWidget);

    // The PIN starts over, so it takes 6 new digits to sign in.
    await enterPin(tester, '12345');
    expect(signedIn, isNull, reason: 'only 5 digits since the PIN was cleared');
    await enterPin(tester, '6');
    expect(signedIn, 'Dan Finkle');
  });

  testWidgets('The employee screen passes the name and PIN, and shows the message it gets back', (tester) async {
    final calls = <(String, String)>[];
    await showPage(
      tester,
      EmployeeLoginPage(onSignIn: (name, pin) {
        calls.add((name, pin));
        return 'Server says no';
      }),
    );

    await enterPin(tester, '246810');

    expect(calls, [('Dan Finkle', '246810')]);
    expect(find.widgetWithText(ErrorBox, 'Server says no'), findsOneWidget);
  });

  testWidgets('ErrorBox shows its message next to an error icon', (tester) async {
    await showPage(tester, const Scaffold(body: ErrorBox('Something went wrong')));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.descendant(of: find.byType(ErrorBox), matching: find.byIcon(Icons.error_outline)), findsOneWidget);
  });
}
