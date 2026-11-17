import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/models/employee.dart';
import 'package:imp_app/screens/login/employee_login_page.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  const daniel = Employee(id: 1, name: 'Daniel Finkle');
  const grace = Employee(id: 4, name: 'Grace Kim');

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tap(tester, find.text(digit));
    }
  }

  /// Shows the page with these employees (or a load that fails or waits), and writes down every sign-in it sends.
  Future<List<(int, String)>> showPage(
    WidgetTester tester, {
    Future<List<Employee>> Function()? loadEmployees,
    Future<String?> Function(int employeeId, String pin)? onSignIn,
    bool showBack = true,
  }) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(int, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: EmployeeLoginPage(
          loadEmployees: loadEmployees ?? () async => [daniel, grace],
          onSignIn: (employeeId, pin) async {
            calls.add((employeeId, pin));
            return onSignIn == null ? null : await onSignIn(employeeId, pin);
          },
          showBack: showBack,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  group('The name list', () {
    testWidgets('Shows a spinner until the names arrive', (tester) async {
      final names = Completer<List<Employee>>();
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: EmployeeLoginPage(loadEmployees: () => names.future, onSignIn: (_, _) async => null),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<Employee>), findsNothing);

      names.complete([daniel]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Daniel Finkle'), findsOneWidget);
    });

    testWidgets('Starts on the first name the server sent', (tester) async {
      await showPage(tester);

      expect(find.text('Daniel Finkle'), findsOneWidget);
      expect(find.text('Grace Kim'), findsNothing, reason: 'the dropdown is closed, so only the picked name shows');
    });

    testWidgets('Opening the dropdown shows every name', (tester) async {
      await showPage(tester);

      await tap(tester, find.text('Daniel Finkle'));

      expect(find.text('Grace Kim'), findsOneWidget);
    });

    testWidgets('If the names can\'t load, shows why, with no dropdown, and the keypad sends nothing', (tester) async {
      final calls = await showPage(
        tester,
        loadEmployees: () async =>
            throw ApiException("Can't reach the server. Check the connection and try again.", screen: 'Test'),
      );

      expect(
        find.widgetWithText(ErrorBox, "Can't reach the server. Check the connection and try again."),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<Employee>), findsNothing);
      await enterPin(tester, '111111');
      expect(calls, isEmpty);
    });

    testWidgets('With nobody to sign in, the keypad sends nothing', (tester) async {
      final calls = await showPage(tester, loadEmployees: () async => []);

      await enterPin(tester, '111111');

      expect(calls, isEmpty);
    });

    testWidgets('A reply in an unexpected shape shows why instead of spinning forever', (tester) async {
      // What AuthApi.activeEmployees throws when the reply has no employees list.
      final calls = await showPage(tester, loadEmployees: () async => throw TypeError());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(ErrorBox, 'The list of names could not be read.'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<Employee>), findsNothing);
      await enterPin(tester, '111111');
      expect(calls, isEmpty);
    });

    testWidgets('No Try again once the names have loaded', (tester) async {
      await showPage(tester);

      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('Try again shows when the names failed to load', (tester) async {
      await showPage(
        tester,
        loadEmployees: () async =>
            throw ApiException("Can't reach the server. Check the connection and try again.", screen: 'Test'),
      );

      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('A refused PIN does not show Try again', (tester) async {
      await showPage(tester, onSignIn: (_, _) async => 'Incorrect PIN. Try again.');

      await enterPin(tester, '000000');

      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsNothing);
    });

    testWidgets('Try again loads the names, clears the error, and sign-in works', (tester) async {
      var loads = 0;
      final calls = await showPage(
        tester,
        loadEmployees: () async {
          if (++loads == 1) {
            throw ApiException("Can't reach the server. Check the connection and try again.", screen: 'Test');
          }
          return [daniel, grace];
        },
      );

      await tap(tester, find.text('Try again'));

      expect(loads, 2);
      expect(find.byType(ErrorBox), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Daniel Finkle'), findsOneWidget);
      await enterPin(tester, '111111');
      expect(calls, [(1, '111111')]);
    });

    testWidgets('Try again shows the spinner while it loads, and the error again if it still fails', (tester) async {
      final second = Completer<List<Employee>>();
      var loads = 0;
      await showPage(
        tester,
        loadEmployees: () {
          if (++loads == 1) return Future.error(ApiException('The server is down.', screen: 'Test'));
          return second.future;
        },
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ErrorBox), findsNothing);

      second.completeError(ApiException('The server is still down.', screen: 'Test'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorBox, 'The server is still down.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('The PIN', () {
    testWidgets('The 6th digit sends the picked employee\'s id and the PIN', (tester) async {
      final calls = await showPage(tester);

      await enterPin(tester, '01234');
      expect(calls, isEmpty, reason: 'the 6th digit signs in, not the 5th');

      await enterPin(tester, '5');
      expect(calls, [(1, '012345')], reason: 'the PIN keeps its leading zero');
    });

    testWidgets('Picking another name sends that employee\'s id', (tester) async {
      final calls = await showPage(tester);

      await tap(tester, find.text('Daniel Finkle'));
      await tap(tester, find.text('Grace Kim').last);
      await enterPin(tester, '444444');

      expect(calls, [(4, '444444')]);
    });

    testWidgets('Delete removes the last digit', (tester) async {
      final calls = await showPage(tester);

      await enterPin(tester, '12345');
      await tap(tester, find.bySemanticsLabel('Delete'));
      await enterPin(tester, '6');
      expect(calls, isEmpty, reason: 'only 5 digits after the delete');

      await enterPin(tester, '7');
      expect(calls, [(1, '123467')]);
    });

    testWidgets('No error box shows before a failed sign-in', (tester) async {
      await showPage(tester);

      expect(find.byType(ErrorBox), findsNothing);
    });

    testWidgets('A refused PIN shows the server\'s sentence and clears the PIN for another try', (tester) async {
      var tries = 0;
      final calls = await showPage(tester, onSignIn: (_, _) async => ++tries == 1 ? 'Incorrect PIN. Try again.' : null);

      await enterPin(tester, '000000');
      expect(find.widgetWithText(ErrorBox, 'Incorrect PIN. Try again.'), findsOneWidget);

      // The PIN starts over, so it takes 6 new digits to try again.
      await enterPin(tester, '11111');
      expect(calls.length, 1, reason: 'only 5 digits since the PIN was cleared');
      await enterPin(tester, '1');
      expect(calls.last, (1, '111111'));
    });

    testWidgets('Picking another name clears the error and the PIN', (tester) async {
      final calls = await showPage(tester, onSignIn: (_, _) async => 'Incorrect PIN. Try again.');
      await enterPin(tester, '000000');

      await enterPin(tester, '123');
      await tap(tester, find.text('Daniel Finkle'));
      await tap(tester, find.text('Grace Kim').last);

      expect(find.byType(ErrorBox), findsNothing);
      await enterPin(tester, '444444');
      expect(calls.last, (4, '444444'), reason: 'the 3 digits from before were cleared');
    });
  });

  group('Back', () {
    testWidgets('Shows Back by default, and Back closes the page', (tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EmployeeLoginPage(loadEmployees: () async => [daniel], onSignIn: (_, _) async => null),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Open'));

      await tap(tester, find.text('Back'));

      expect(find.byType(EmployeeLoginPage), findsNothing);
    });

    testWidgets('Switch user\'s version has no Back', (tester) async {
      await showPage(tester, showBack: false);

      expect(find.text('Back'), findsNothing);
    });
  });

  group('While the PIN is being checked', () {
    final keys = find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell));
    final back = find.widgetWithText(OutlinedButton, 'Back');

    bool keypadEnabled(WidgetTester tester) => tester.widgetList<InkWell>(keys).every((key) => key.onTap != null);
    bool backEnabled(WidgetTester tester) => tester.widget<OutlinedButton>(back).onPressed != null;
    bool nameEnabled(WidgetTester tester) =>
        tester.widget<DropdownButton<Employee>>(find.byType(DropdownButton<Employee>)).onChanged != null;

    testWidgets('the keypad, the name, and Back are disabled', (tester) async {
      final reply = Completer<String?>();
      await showPage(tester, onSignIn: (_, _) => reply.future);
      expect(keypadEnabled(tester), isTrue);
      expect(backEnabled(tester), isTrue);
      expect(nameEnabled(tester), isTrue);

      await enterPin(tester, '123456');

      expect(keypadEnabled(tester), isFalse);
      expect(backEnabled(tester), isFalse);
      expect(nameEnabled(tester), isFalse);

      // Everything comes back once the answer arrives.
      reply.complete('Incorrect PIN. Try again.');
      await tester.pumpAndSettle();
      expect(keypadEnabled(tester), isTrue);
      expect(backEnabled(tester), isTrue);
      expect(nameEnabled(tester), isTrue);
    });

    testWidgets('mashing the keypad sends nothing more', (tester) async {
      final reply = Completer<String?>();
      final calls = await showPage(tester, onSignIn: (_, _) => reply.future);

      await enterPin(tester, '123456');
      await enterPin(tester, '789012');
      await tap(tester, find.bySemanticsLabel('Delete'));

      expect(calls, [(1, '123456')], reason: 'only the first PIN was sent');

      // After a refused PIN the keypad works again and starts from an empty PIN.
      reply.complete('Incorrect PIN. Try again.');
      await tester.pumpAndSettle();
      await enterPin(tester, '654321');
      expect(calls, [(1, '123456'), (1, '654321')]);
    });
  });

  testWidgets('ErrorBox shows its message next to an error icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: ErrorBox('Something went wrong')),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.descendant(of: find.byType(ErrorBox), matching: find.byIcon(Icons.error_outline)), findsOneWidget);
  });
}
