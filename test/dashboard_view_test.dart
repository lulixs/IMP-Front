import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/dashboard.dart';
import 'package:imp_app/screens/dashboard/dashboard_view.dart';
import 'package:imp_app/theme.dart';

void main() {
  DashboardCategory category(int id, int full, int half, int empty) {
    return DashboardCategory(
      id: id,
      name: 'Category $id',
      symbol: null,
      fullCount: full,
      halfCount: half,
      emptyCount: empty,
      storedTooLongCount: 0,
    );
  }

  Future<void> showView(WidgetTester tester, List<DashboardCategory> categories, {bool isSample = false}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: DashboardView(
            data: DashboardData(alertThresholdDays: 180, categories: categories),
            isSample: isSample,
          ),
        ),
      ),
    );
  }

  testWidgets('The headline adds up every category', (tester) async {
    await showView(tester, [category(1, 3, 2, 1), category(2, 0, 0, 0), category(3, 1, 1, 0)]);

    expect(find.text('8 racked boxes in 3 categories.'), findsOneWidget);
  });

  testWidgets('The headline uses singular words for 1', (tester) async {
    await showView(tester, [category(1, 1, 0, 0)]);

    expect(find.text('1 racked box in 1 category.'), findsOneWidget);
  });

  testWidgets('With no categories it says so', (tester) async {
    await showView(tester, []);

    expect(find.text('0 racked boxes in 0 categories.'), findsOneWidget);
    expect(find.text('No categories yet.'), findsOneWidget);
  });

  testWidgets('Sample data is called out in the headline', (tester) async {
    await showView(tester, [category(1, 3, 2, 1)], isSample: true);

    expect(find.text('6 racked boxes in 1 category. Sample data, not from the server.'), findsOneWidget);
  });

  testWidgets('Shows the title and the fullness key', (tester) async {
    await showView(tester, [category(1, 3, 2, 1)]);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Unracked and deleted boxes are not counted'), findsOneWidget);
  });
}
