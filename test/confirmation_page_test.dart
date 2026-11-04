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

  Future<void> showPage(WidgetTester tester, VoidCallback onConfirm) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: ConfirmationPage(data: data, onConfirm: onConfirm),
      ),
    );
  }

  testWidgets('Shows the email, tablet name, and employee name', (tester) async {
    await showPage(tester, () {});

    expect(find.text('store@example.org'), findsOneWidget);
    expect(find.text('Front desk'), findsOneWidget);
    expect(find.text('Mabel'), findsOneWidget);
  });

  testWidgets('The password and PIN are hidden until their eye is tapped', (tester) async {
    await showPage(tester, () {});

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

  testWidgets('Confirm calls onConfirm', (tester) async {
    var confirmed = false;
    await showPage(tester, () => confirmed = true);

    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));

    expect(confirmed, isTrue);
  });
}
