import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/screens/dashboard/category_card.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  Future<void> showPage(WidgetTester tester, {double textScale = 1}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const DashboardPage(),
      ),
    );
  }

  testWidgets('Shows the sample category as one card marked SAMPLE', (tester) async {
    await showPage(tester);

    expect(find.byType(CategoryCard), findsOneWidget);
    expect(find.text('📦 Sample category'), findsOneWidget);
    expect(find.text('SAMPLE'), findsOneWidget);
    expect(find.text('6 racked boxes'), findsOneWidget);
    expect(find.text('2 stored too long'), findsOneWidget);
    expect(find.textContaining('Sample data, not from the server.'), findsOneWidget);
  });

  testWidgets('A larger system text size makes the card taller instead of overflowing', (tester) async {
    await showPage(tester, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.byType(CategoryCard), findsOneWidget);
  });
}
