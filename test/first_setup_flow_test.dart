import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/setup/confirmation_page.dart';
import 'package:imp_app/screens/setup/first_employee_page.dart';
import 'package:imp_app/screens/setup/first_setup_flow.dart';
import 'package:imp_app/screens/setup/master_account_page.dart';
import 'package:imp_app/screens/setup/tablet_name_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  final fields = find.byType(TextFormField);

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> showFlow(WidgetTester tester, void Function(FirstSetupData data) onFinished) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: FirstSetupFlow(onFinished: onFinished),
      ),
    );
  }

  Future<void> fillMasterAccount(WidgetTester tester) async {
    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.enterText(fields.at(2), 'secret123');
    await tapButton(tester, 'Next');
  }

  Future<void> fillTabletName(WidgetTester tester) async {
    await tester.enterText(fields.first, 'Front desk');
    await tapButton(tester, 'Next');
  }

  Future<void> fillFirstEmployee(WidgetTester tester) async {
    await tester.enterText(fields.at(0), 'Mabel');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    await tapButton(tester, 'Next');
  }

  testWidgets('All four steps finish with everything that was entered', (tester) async {
    FirstSetupData? data;
    await showFlow(tester, (d) => data = d);

    await fillMasterAccount(tester);
    expect(find.byType(TabletNamePage), findsOneWidget);
    await fillTabletName(tester);
    expect(find.byType(FirstEmployeePage), findsOneWidget);
    await fillFirstEmployee(tester);
    expect(find.byType(ConfirmationPage), findsOneWidget);
    expect(data, isNull, reason: 'nothing is finished until Confirm is tapped');

    await tapButton(tester, 'Confirm');

    expect(data, isNotNull);
    expect(data!.masterEmail, 'store@example.org');
    expect(data!.masterPassword, 'secret123');
    expect(data!.tabletName, 'Front desk');
    expect(data!.employeeName, 'Mabel');
    expect(data!.employeePin, '123456');
  });

  testWidgets('Back on each step returns to the one before with its fields still filled in', (tester) async {
    await showFlow(tester, (_) {});

    await fillMasterAccount(tester);
    await fillTabletName(tester);
    await fillFirstEmployee(tester);

    await tapButton(tester, 'Back');
    expect(find.byType(FirstEmployeePage), findsOneWidget);
    expect(find.text('Mabel'), findsOneWidget);

    await tapButton(tester, 'Back');
    expect(find.byType(TabletNamePage), findsOneWidget);
    expect(find.text('Front desk'), findsOneWidget);

    await tapButton(tester, 'Back');
    expect(find.byType(MasterAccountPage), findsOneWidget);
    expect(find.text('store@example.org'), findsOneWidget);
    expect(find.text('Back'), findsNothing, reason: 'step 1 has no Back button');
  });

  testWidgets("The tablet's back button also returns to the previous step", (tester) async {
    await showFlow(tester, (_) {});

    await fillMasterAccount(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(MasterAccountPage), findsOneWidget);
    expect(find.text('store@example.org'), findsOneWidget);
  });

  testWidgets('Every step counts out of 4', (tester) async {
    await showFlow(tester, (_) {});

    expect(find.textContaining('step 1 of 4.'), findsOneWidget);
    await fillMasterAccount(tester);
    expect(find.textContaining('step 2 of 4.'), findsOneWidget);
    await fillTabletName(tester);
    expect(find.textContaining('step 3 of 4.'), findsOneWidget);
    await fillFirstEmployee(tester);
    expect(find.textContaining('step 4 of 4.'), findsOneWidget);
    expect(find.text('4. Confirmation'), findsOneWidget);
  });
}
