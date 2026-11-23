import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/box_query.dart';
import 'package:imp_app/models/category.dart';
import 'package:imp_app/screens/boxes/boxes_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  // Every search or filter the page reported, in order
  late List<BoxQuery> queries;

  setUp(() => queries = []);

  Future<void> showPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: BoxesPage(
            categories: const [
              Category(id: 1, name: 'Coats', symbol: null),
              Category(id: 2, name: 'Christmas', symbol: '🎄'),
            ],
            boxes: const [],
            loading: false,
            error: null,
            onQueryChanged: queries.add,
            onOpenBox: (_) {},
            onNewBox: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
  }

  // Opens a dropdown and taps an item. pumpAndSettle moves the clock on, so a typing wait that was
  // already running would finish during it.
  Future<void> pick(WidgetTester tester, Finder dropdown, String item) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  final category = find.byType(DropdownButtonFormField<int>);
  final rack = find.byType(DropdownButtonFormField<RackFilter>);
  final sort = find.byType(DropdownButtonFormField<BoxSort>);

  group('typing', () {
    testWidgets('asks 300 ms after the last key, not before', (tester) async {
      await showPage(tester);

      await tester.enterText(find.byType(TextField), 'coat');
      await tester.pump(const Duration(milliseconds: 299));
      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(queries.map((q) => q.search), ['coat']);
    });

    testWidgets('each key starts the wait over, so a burst of typing asks once', (tester) async {
      await showPage(tester);

      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'co');
      await tester.pump(const Duration(milliseconds: 200));
      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      expect(queries.map((q) => q.search), ['co']);
    });

    testWidgets('typing back to what was already asked does not ask again', (tester) async {
      await showPage(tester);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 500));

      expect(queries.length, 1);
    });
  });

  group('filters', () {
    testWidgets('the category filter asks right away', (tester) async {
      await showPage(tester);
      await pick(tester, category, 'Coats');
      expect(queries.single.categoryId, 1);
    });

    testWidgets('All categories clears the category', (tester) async {
      await showPage(tester);
      await pick(tester, category, '🎄 Christmas');
      expect(queries.last.categoryId, 2);

      await pick(tester, category, 'All categories');
      expect(queries.last.categoryId, isNull);
    });

    testWidgets('the Rack filter asks for racked, unracked, and all', (tester) async {
      await showPage(tester);

      await pick(tester, rack, 'Rack: Racked');
      expect(queries.last.rack, RackFilter.racked);

      await pick(tester, rack, 'Rack: Unracked');
      expect(queries.last.rack, RackFilter.unracked);

      await pick(tester, rack, 'Rack: All');
      expect(queries.last.rack, RackFilter.all);
      expect(queries.length, 3);
    });

    testWidgets('the order filter asks for newest first, then oldest first', (tester) async {
      await showPage(tester);

      await pick(tester, sort, 'Newest first');
      expect(queries.last.sort, BoxSort.newest);

      await pick(tester, sort, 'Oldest first');
      expect(queries.last.sort, BoxSort.oldest);
      expect(queries.length, 2);
    });

    testWidgets('each change keeps the filters chosen before it', (tester) async {
      await showPage(tester);

      await pick(tester, category, 'Coats');
      await pick(tester, rack, 'Rack: Unracked');
      await pick(tester, sort, 'Newest first');

      final last = queries.last;
      expect(last.categoryId, 1);
      expect(last.rack, RackFilter.unracked);
      expect(last.sort, BoxSort.newest);
      expect(queries.length, 3);
    });

    testWidgets('a filter change sends the typed text with it and cancels the typing wait', (tester) async {
      await showPage(tester);

      await tester.enterText(find.byType(TextField), 'coat');

      // Open the menu and choose within 200 ms, before the 300 ms typing wait ends
      await tester.tap(sort);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Newest first').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(queries.single.search, 'coat');
      expect(queries.single.sort, BoxSort.newest);

      // Nothing more is sent when the typing wait would have ended
      await tester.pump(const Duration(milliseconds: 500));
      expect(queries.length, 1);
    });

    testWidgets('typing after a filter keeps the filter', (tester) async {
      await showPage(tester);

      await pick(tester, category, 'Coats');
      await tester.enterText(find.byType(TextField), 'zip');
      await tester.pump(const Duration(milliseconds: 300));

      expect(queries.last.search, 'zip');
      expect(queries.last.categoryId, 1);
      expect(queries.length, 2);
    });
  });
}
