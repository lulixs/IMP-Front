import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/box.dart';
import 'package:imp_app/models/building.dart';
import 'package:imp_app/models/category.dart';
import 'package:imp_app/models/new_box.dart';
import 'package:imp_app/screens/boxes/new_box_page.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/box_helpers.dart';

void main() {
  late List<NewBox> saved;

  setUp(() => saved = []);

  DateTime today() => DateUtils.dateOnly(DateTime.now());

  Future<void> showPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: NewBoxPage(
          categories: const [Category(id: 1, name: 'Coats', symbol: null)],
          buildings: const [Building(id: 2, name: 'Processing Center')],
          onSave: (box) async => saved.add(box),
          onSaveAndPrint: (box) async => saved.add(box),
        ),
      ),
    );
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.text(formatDate(today())));
    await tester.pumpAndSettle();
  }

  // Fills the required fields, so the form can be saved
  Future<void> fillRequired(WidgetTester tester) async {
    final dropdowns = find.byType(DropdownButtonFormField<int>);
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coats').last);
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Processing Center').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'a');
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<int>), matching: find.text('2')));
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<Fullness>), matching: find.text('Full')));
    await tester.pump();
  }

  testWidgets('the storage date starts as today', (tester) async {
    await showPage(tester);
    expect(find.text(formatDate(today())), findsOneWidget);
  });

  testWidgets('a box saved without touching the date is dated today', (tester) async {
    await showPage(tester);
    await fillRequired(tester);

    await tester.tap(find.text('Save box'));
    await tester.pump();

    expect(saved.single.rackedSince, today());
  });

  testWidgets('the calendar opens on today and cannot go past it', (tester) async {
    await showPage(tester);
    await openCalendar(tester);

    final calendar = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(DateUtils.dateOnly(calendar.initialDate!), today());
    expect(DateUtils.dateOnly(calendar.lastDate), today());
  });

  testWidgets('the calendar has no way to a later month', (tester) async {
    await showPage(tester);
    await openCalendar(tester);

    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);
  });

  testWidgets('an earlier date can be chosen, shows in the field, and is saved', (tester) async {
    await showPage(tester);
    await openCalendar(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final earlier = DateTime(now.year, now.month - 1, 15);
    expect(find.text(formatDate(earlier)), findsOneWidget);

    await fillRequired(tester);
    await tester.tap(find.text('Save box'));
    await tester.pump();
    expect(saved.single.rackedSince, earlier);
  });

  testWidgets('cancelling the calendar keeps the date', (tester) async {
    await showPage(tester);
    await openCalendar(tester);

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text(formatDate(today())), findsOneWidget);
  });
}
