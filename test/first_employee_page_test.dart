import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/setup/first_employee_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  final fields = find.byType(TextFormField);
  Finder nameField() => fields.at(0);
  Finder pinField() => fields.at(1);
  Finder confirmField() => fields.at(2);

  Future<void> tapNext(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump();
  }

  Future<void> showPage(WidgetTester tester, void Function(String name, String pin) onNext) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: FirstEmployeePage(onNext: onNext),
      ),
    );
  }

  testWidgets('Empty fields show errors and do not continue', (tester) async {
    var continued = false;
    await showPage(tester, (_, _) => continued = true);

    await tapNext(tester);

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter 6 digits'), findsOneWidget);
    expect(continued, isFalse);
  });

  testWidgets('A blank name is rejected', (tester) async {
    await showPage(tester, (_, _) {});

    await tester.enterText(nameField(), '   ');
    await tapNext(tester);

    expect(find.text('Enter a name'), findsOneWidget);
  });

  testWidgets('The PIN needs exactly 6 digits and ignores anything else', (tester) async {
    await showPage(tester, (_, _) {});

    await tester.enterText(pinField(), '12345');
    await tapNext(tester);
    expect(find.text('Enter 6 digits'), findsOneWidget);

    // Letters are dropped and typing stops at 6 digits.
    await tester.enterText(pinField(), '12ab34567');
    expect(tester.widget<TextFormField>(pinField()).controller!.text, '123456');
  });

  testWidgets('Mismatched PINs show an error', (tester) async {
    await showPage(tester, (_, _) {});

    await tester.enterText(nameField(), 'Mabel');
    await tester.enterText(pinField(), '123456');
    await tester.enterText(confirmField(), '123457');
    await tapNext(tester);

    expect(find.text('PINs do not match'), findsOneWidget);
  });

  testWidgets('Valid fields continue with the trimmed name and the PIN', (tester) async {
    String? name;
    String? pin;
    await showPage(tester, (n, p) {
      name = n;
      pin = p;
    });

    await tester.enterText(nameField(), ' Mabel ');
    await tester.enterText(pinField(), '123456');
    await tester.enterText(confirmField(), '123456');
    await tapNext(tester);

    expect(name, 'Mabel');
    expect(pin, '123456');
  });
}
