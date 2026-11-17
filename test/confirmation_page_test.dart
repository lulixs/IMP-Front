import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/setup/confirmation_page.dart';
import 'package:imp_app/screens/setup/first_setup_data.dart';
import 'package:imp_app/theme.dart';

void main() {
  const data = FirstSetupData(
    masterEmail: 'store@example.org',
    masterPassword: 'secret123',
    tabletName: 'Front desk',
    employeeName: 'Mabel',
    employeePin: '123456',
  );

  Future<void> showPage(WidgetTester tester, Future<String?> Function() onConfirm) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: ConfirmationPage(data: data, onConfirm: onConfirm),
      ),
    );
  }

  testWidgets('Shows the email, tablet name, and employee name', (tester) async {
    await showPage(tester, () async => null);

    expect(find.text('store@example.org'), findsOneWidget);
    expect(find.text('Front desk'), findsOneWidget);
    expect(find.text('Mabel'), findsOneWidget);
  });

  testWidgets('The password and PIN are hidden until their eye is tapped', (tester) async {
    await showPage(tester, () async => null);

    expect(find.text('secret123'), findsNothing);
    expect(find.text('123456'), findsNothing);

    await tester.tap(find.byTooltip('Show').first);
    await tester.pump();
    expect(find.text('secret123'), findsOneWidget);
    expect(find.text('123456'), findsNothing);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();
    expect(find.text('secret123'), findsNothing);
  });

  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
  }

  // The Confirm button, so tests can check whether it can be tapped.
  FilledButton confirmButton(WidgetTester tester) {
    return tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'));
  }

  testWidgets('Confirm calls onConfirm', (tester) async {
    var confirmed = false;
    await showPage(tester, () async {
      confirmed = true;
      return null;
    });

    await tapConfirm(tester);

    expect(confirmed, isTrue);
  });

  testWidgets('Shows no error box before Confirm is tapped', (tester) async {
    await showPage(tester, () async => 'This store is already set up. Set up this tablet instead.');

    expect(find.text('This store is already set up. Set up this tablet instead.'), findsNothing);
  });

  testWidgets('Shows the sentence onConfirm returns, in the error box', (tester) async {
    await showPage(tester, () async => 'This store is already set up. Set up this tablet instead.');

    await tapConfirm(tester);

    expect(find.text('This store is already set up. Set up this tablet instead.'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNotNull, reason: 'Confirm can be tapped again after an error');
  });

  testWidgets('Confirm is disabled while waiting for the answer, and only sends once', (tester) async {
    // A Completer is an answer that arrives only when the test says so, so the test can look at the
    // page while it is still waiting.
    final answer = Completer<String?>();
    var calls = 0;
    await showPage(tester, () {
      calls++;
      return answer.future;
    });

    await tapConfirm(tester);
    expect(confirmButton(tester).onPressed, isNull, reason: 'greyed out while waiting');
    await tester.tap(find.text('Confirm'));
    expect(calls, 1);

    answer.complete('Enter a valid email.');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.text('Enter a valid email.'), findsOneWidget);
  });

  testWidgets('A second try clears the first error once it works', (tester) async {
    var tries = 0;
    await showPage(tester, () async => ++tries == 1 ? 'Enter a valid email.' : null);

    await tapConfirm(tester);
    expect(find.text('Enter a valid email.'), findsOneWidget);

    await tapConfirm(tester);
    expect(find.text('Enter a valid email.'), findsNothing);
  });
}
