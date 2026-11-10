import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  final fields = find.byType(TextFormField);
  final signInButton = find.widgetWithText(FilledButton, 'Sign in');

  /// Each sign-in the page reports: email, password, tablet name.
  late List<(String, String, String?)> calls;

  /// Shows the page in [mode]. Every sign-in is recorded in [calls] and gets [reply] back.
  Future<void> showPage(WidgetTester tester, MasterLoginMode mode, {String? reply}) {
    calls = [];
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        // A new key each time, so a test that loops over the modes starts each one fresh.
        home: MasterLoginPage(
          key: UniqueKey(),
          mode: mode,
          onSignIn: (email, password, tabletName) {
            calls.add((email, password, tabletName));
            return reply;
          },
        ),
      ),
    );
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();
  }

  testWidgets('Each mode has its own subtitle', (tester) async {
    const subtitles = {
      MasterLoginMode.masterToggle: 'Sign in with the Master account to unlock Master-only pages.',
      MasterLoginMode.signIn: 'Sign in with the master account to use IMP on this tablet.',
      MasterLoginMode.newTablet:
          'Sign in with the Master account to add this tablet. The first tablet is set up during first-time setup.',
    };
    for (final MapEntry(key: mode, value: subtitle) in subtitles.entries) {
      await showPage(tester, mode);
      expect(find.text(subtitle), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('Only adding a new tablet asks for the tablet name', (tester) async {
    for (final mode in MasterLoginMode.values) {
      await showPage(tester, mode);
      final expected = mode == MasterLoginMode.newTablet ? findsOneWidget : findsNothing;
      expect(find.text('Tablet name'), expected, reason: '$mode');
      expect(fields, findsNWidgets(mode == MasterLoginMode.newTablet ? 3 : 2), reason: '$mode');
    }
  });

  testWidgets('The tablet name field is above the email', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    expect(tester.getTopLeft(find.text('Tablet name')).dy, lessThan(tester.getTopLeft(find.text('Email')).dy));
  });

  testWidgets('Without the tablet name field, the email and password are passed with no tablet name', (tester) async {
    for (final mode in [MasterLoginMode.masterToggle, MasterLoginMode.signIn]) {
      await showPage(tester, mode, reply: 'Server says no');

      await tester.enterText(fields.at(0), '  store@example.org  ');
      await tester.enterText(fields.at(1), ' secret ');
      await tapSignIn(tester);

      expect(calls, [('store@example.org', ' secret ', null)], reason: '$mode');
      expect(find.widgetWithText(ErrorBox, 'Server says no'), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('Adding a new tablet passes the trimmed tablet name too', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    await tester.enterText(fields.at(0), '  Front desk #2  ');
    await tester.enterText(fields.at(1), 'store@example.org');
    await tester.enterText(fields.at(2), 'secret');
    await tapSignIn(tester);

    expect(calls, [('store@example.org', 'secret', 'Front desk #2')]);
  });

  testWidgets('A blank tablet name shows the error and does not sign in', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    await tester.enterText(fields.at(0), '   ');
    await tester.enterText(fields.at(1), 'store@example.org');
    await tester.enterText(fields.at(2), 'secret');
    await tapSignIn(tester);

    expect(find.text('Enter a tablet name'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('The tablet name is capped at 100 characters, like in first-time setup', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    await tester.enterText(fields.at(0), 'x' * 150);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, 'x' * 100);
  });

  testWidgets('Sign-in is not called while any field is invalid', (tester) async {
    for (final mode in MasterLoginMode.values) {
      await showPage(tester, mode);

      await tapSignIn(tester);

      expect(calls, isEmpty, reason: '$mode');
      expect(find.text('Enter an email'), findsOneWidget, reason: '$mode');
      expect(find.text('Enter a password'), findsOneWidget, reason: '$mode');
      expect(find.byType(ErrorBox), findsNothing, reason: '$mode');
    }
  });
}
