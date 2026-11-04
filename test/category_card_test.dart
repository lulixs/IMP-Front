import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/dashboard.dart';
import 'package:imp_app/screens/dashboard/category_card.dart';
import 'package:imp_app/theme.dart';

void main() {
  DashboardCategory category({
    String name = 'Coats',
    String? symbol = '🧥',
    int full = 3,
    int half = 2,
    int empty = 1,
    int storedTooLong = 0,
  }) {
    return DashboardCategory(
      id: 1,
      name: name,
      symbol: symbol,
      fullCount: full,
      halfCount: half,
      emptyCount: empty,
      storedTooLongCount: storedTooLong,
    );
  }

  Future<void> showCard(WidgetTester tester, DashboardCategory c, {bool isSample = false}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 260, child: CategoryCard(category: c, isSample: isSample))),
        ),
      ),
    );
  }

  testWidgets('Shows the symbol and name, total, and the three counts', (tester) async {
    await showCard(tester, category());

    expect(find.text('🧥 Coats'), findsOneWidget);
    expect(find.text('6 racked boxes'), findsOneWidget);
    expect(find.text('3 full   2 half   1 empty'), findsOneWidget);
  });

  testWidgets('A category without a symbol shows the name alone', (tester) async {
    await showCard(tester, category(name: 'Easter Baskets', symbol: null));

    expect(find.text('Easter Baskets'), findsOneWidget);
  });

  testWidgets('One box says "racked box"', (tester) async {
    await showCard(tester, category(full: 1, half: 0, empty: 0));

    expect(find.text('1 racked box'), findsOneWidget);
  });

  testWidgets('A category with 0 boxes draws without errors', (tester) async {
    await showCard(tester, category(full: 0, half: 0, empty: 0));

    expect(tester.takeException(), isNull);
    expect(find.text('0 full   0 half   0 empty'), findsOneWidget);
  });

  testWidgets('Shows "No alerts" or how many are stored too long', (tester) async {
    await showCard(tester, category(storedTooLong: 0));
    expect(find.text('No alerts'), findsOneWidget);

    await showCard(tester, category(storedTooLong: 2));
    expect(find.text('2 stored too long'), findsOneWidget);
    expect(find.text('No alerts'), findsNothing);
  });

  testWidgets('The SAMPLE tag shows only for sample data', (tester) async {
    await showCard(tester, category());
    expect(find.text('SAMPLE'), findsNothing);

    await showCard(tester, category(), isSample: true);
    expect(find.text('SAMPLE'), findsOneWidget);
  });
}
