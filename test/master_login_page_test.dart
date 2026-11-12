import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  final fields = find.byType(TextFormField);
  final cancel = find.widgetWithText(OutlinedButton, 'Cancel');

  /// Each sign-in the page reports: email, password, tablet name.
  late List<(String, String, String?)> calls;

  void setSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The page in [mode]. Every sign-in is recorded in [calls] and answered with [reply],
  /// which can be a Completer's future to keep the page waiting.
  MasterLoginPage page(MasterLoginMode mode, {Future<String?>? reply}) {
    return MasterLoginPage(
      // A new key each time, so a test that loops over the modes starts each one fresh.
      key: UniqueKey(),
      mode: mode,
      onSignIn: (email, password, tabletName) {
        calls.add((email, password, tabletName));
        return reply ?? Future.value(null);
      },
    );
  }

  /// Shows the page in [mode] as the app's first screen.
  Future<void> showPage(WidgetTester tester, MasterLoginMode mode, {Future<String?>? reply}) {
    calls = [];
    setSize(tester);
    return tester.pumpWidget(MaterialApp(theme: buildTheme(), home: page(mode, reply: reply)));
  }

  /// Opens the page in [mode] on top of a blank screen, the way the sidebar opens it, so it
  /// can be closed. Returns a list that gets whatever the page was closed with.
  Future<List<Object?>> pushPage(WidgetTester tester, MasterLoginMode mode, {Future<String?>? reply}) async {
    calls = [];
    setSize(tester);
    final results = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page(mode, reply: reply))),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder button(MasterLoginMode mode) =>
      find.widgetWithText(FilledButton, mode == MasterLoginMode.newTablet ? 'Set up Tablet' : 'Sign In');

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Fills in valid values, with a tablet name only when the mode asks for one.
  Future<void> fillIn(WidgetTester tester, MasterLoginMode mode) async {
    var i = 0;
    if (mode == MasterLoginMode.newTablet) await tester.enterText(fields.at(i++), 'Front desk');
    await tester.enterText(fields.at(i++), 'store@example.org');
    await tester.enterText(fields.at(i), 'secret');
  }

  testWidgets('Each mode has its own title, subtitle, and button label', (tester) async {
    const expected = {
      MasterLoginMode.masterToggle: (
        'Activate Master Mode',
        'Sign in with the Master account to unlock Master-only pages.',
        'Sign In',
      ),
      MasterLoginMode.signIn: ('Sign In', 'Sign in with the Master account to use IMP on this tablet.', 'Sign In'),
      MasterLoginMode.newTablet: (
        'Tablet Setup',
        'Sign in with the Master account to add this tablet.',
        'Set up Tablet',
      ),
    };
    for (final MapEntry(key: mode, value: (title, subtitle, label)) in expected.entries) {
      await showPage(tester, mode);
      // The title is the large text above the card. In sign-in mode it matches the button label too.
      expect(find.text(title), findsAtLeastNWidgets(1), reason: '$mode');
      expect(find.text(subtitle), findsOneWidget, reason: '$mode');
      expect(find.widgetWithText(FilledButton, label), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('Only adding a new tablet asks for the tablet name', (tester) async {
    for (final mode in MasterLoginMode.values) {
      await showPage(tester, mode);
      final newTablet = mode == MasterLoginMode.newTablet;
      expect(find.text('Tablet name'), newTablet ? findsOneWidget : findsNothing, reason: '$mode');
      expect(fields, findsNWidgets(newTablet ? 3 : 2), reason: '$mode');
    }
  });

  testWidgets('The tablet name field is above the email', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    expect(tester.getTopLeft(find.text('Tablet name')).dy, lessThan(tester.getTopLeft(find.text('Email')).dy));
  });

  testWidgets('Without the tablet name field, the email and password are passed with no tablet name', (tester) async {
    for (final mode in [MasterLoginMode.masterToggle, MasterLoginMode.signIn]) {
      await showPage(tester, mode, reply: Future.value('Server says no'));

      await tester.enterText(fields.at(0), '  store@example.org  ');
      await tester.enterText(fields.at(1), ' secret ');
      await tap(tester, button(mode));

      expect(calls, [('store@example.org', ' secret ', null)], reason: '$mode');
      expect(find.widgetWithText(ErrorBox, 'Server says no'), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('Adding a new tablet passes the trimmed tablet name too', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    await tester.enterText(fields.at(0), '  Front desk #2  ');
    await tester.enterText(fields.at(1), 'store@example.org');
    await tester.enterText(fields.at(2), 'secret');
    await tap(tester, button(MasterLoginMode.newTablet));

    expect(calls, [('store@example.org', 'secret', 'Front desk #2')]);
  });

  testWidgets('A blank tablet name shows the error and does not sign in', (tester) async {
    await showPage(tester, MasterLoginMode.newTablet);

    await tester.enterText(fields.at(0), '   ');
    await tester.enterText(fields.at(1), 'store@example.org');
    await tester.enterText(fields.at(2), 'secret');
    await tap(tester, button(MasterLoginMode.newTablet));

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

      await tap(tester, button(mode));

      expect(calls, isEmpty, reason: '$mode');
      expect(find.text('Enter an email'), findsOneWidget, reason: '$mode');
      expect(find.text('Enter a password'), findsOneWidget, reason: '$mode');
      expect(find.byType(ErrorBox), findsNothing, reason: '$mode');
    }
  });

  testWidgets('Only the Master mode screen has a Cancel button', (tester) async {
    for (final mode in MasterLoginMode.values) {
      await showPage(tester, mode);
      expect(cancel, mode == MasterLoginMode.masterToggle ? findsOneWidget : findsNothing, reason: '$mode');
    }
  });

  testWidgets('Cancel closes the Master mode screen without signing in', (tester) async {
    final results = await pushPage(tester, MasterLoginMode.masterToggle);

    await tester.enterText(fields.at(0), 'store@example.org');
    await tap(tester, cancel);

    expect(find.byType(MasterLoginPage), findsNothing);
    expect(results, [null]);
    expect(calls, isEmpty);
  });

  group('While the sign-in is being checked', () {
    bool enabled(WidgetTester tester, Finder finder) => tester.widget<ButtonStyleButton>(finder).onPressed != null;

    testWidgets('the button is disabled in every mode, and comes back with the answer', (tester) async {
      for (final mode in MasterLoginMode.values) {
        final reply = Completer<String?>();
        await showPage(tester, mode, reply: reply.future);
        await fillIn(tester, mode);
        expect(enabled(tester, button(mode)), isTrue, reason: '$mode');

        await tap(tester, button(mode));
        expect(enabled(tester, button(mode)), isFalse, reason: '$mode');

        reply.complete('Server says no');
        await tester.pumpAndSettle();
        expect(enabled(tester, button(mode)), isTrue, reason: '$mode');
        expect(find.widgetWithText(ErrorBox, 'Server says no'), findsOneWidget, reason: '$mode');
      }
    });

    testWidgets('mashing the button or the keyboard Enter key sends only one sign-in', (tester) async {
      final reply = Completer<String?>();
      await showPage(tester, MasterLoginMode.signIn, reply: reply.future);
      await fillIn(tester, MasterLoginMode.signIn);

      for (var i = 0; i < 5; i++) {
        await tester.tap(button(MasterLoginMode.signIn), warnIfMissed: false);
        await tester.pump();
      }
      await tester.showKeyboard(fields.at(1));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(calls, hasLength(1));
      reply.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('Cancel and the back button cannot close the Master mode screen', (tester) async {
      final reply = Completer<String?>();
      final results = await pushPage(tester, MasterLoginMode.masterToggle, reply: reply.future);
      await fillIn(tester, MasterLoginMode.masterToggle);
      await tap(tester, button(MasterLoginMode.masterToggle));

      expect(enabled(tester, cancel), isFalse);
      // maybePop is what the system back button does. It respects the page's PopScope.
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(MasterLoginPage), findsOneWidget, reason: 'the back button is blocked while waiting');
      expect(results, isEmpty);

      // Once the answer arrives, Cancel works again.
      reply.complete('Server says no');
      await tester.pumpAndSettle();
      expect(enabled(tester, cancel), isTrue);
      await tap(tester, cancel);
      expect(results, [null]);
    });
  });
}
