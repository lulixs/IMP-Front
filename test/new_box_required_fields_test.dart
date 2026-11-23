import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/building.dart';
import 'package:imp_app/models/box.dart';
import 'package:imp_app/models/category.dart';
import 'package:imp_app/models/new_box.dart';
import 'package:imp_app/screens/boxes/new_box_page.dart';
import 'package:imp_app/theme.dart';

void main() {
  late List<NewBox> saved;
  late List<NewBox> savedAndPrinted;

  setUp(() {
    saved = [];
    savedAndPrinted = [];
  });

  // The reason shown under each field when it is left empty
  const reasons = {
    'category': 'Choose a category.',
    'building': 'Choose a building.',
    'letter': 'Enter 1 to 3 letters',
    'level': 'Choose a level.',
    'fullness': 'Choose how full the box is.',
  };

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
          onSaveAndPrint: (box) async => savedAndPrinted.add(box),
        ),
      ),
    );
  }

  Future<void> pick(WidgetTester tester, Finder dropdown, String item) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  // Fills every required field except the ones named in [leaveOut]
  Future<void> fill(WidgetTester tester, {Set<String> leaveOut = const {}}) async {
    final dropdowns = find.byType(DropdownButtonFormField<int>);
    if (!leaveOut.contains('category')) await pick(tester, dropdowns.at(0), 'Coats');
    if (!leaveOut.contains('building')) await pick(tester, dropdowns.at(1), 'Processing Center');
    // The text fields in order: storage date, shelf letter, notes
    if (!leaveOut.contains('letter')) await tester.enterText(find.byType(TextField).at(1), 'a');
    if (!leaveOut.contains('level')) {
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<int>), matching: find.text('2')));
    }
    if (!leaveOut.contains('fullness')) {
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<Fullness>), matching: find.text('Full')));
    }
    await tester.pump();
  }

  testWidgets('no reasons show before anything is tapped', (tester) async {
    await showPage(tester);
    for (final reason in reasons.values) {
      expect(find.text(reason), findsNothing, reason: reason);
    }
  });

  testWidgets('Save box with an empty form shows every reason and sends nothing', (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Save box'));
    await tester.pump();

    for (final reason in reasons.values) {
      expect(find.text(reason), findsOneWidget, reason: reason);
    }
    expect(saved, isEmpty);
    expect(savedAndPrinted, isEmpty);
  });

  testWidgets('Save and print label checks the same fields', (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Save and print label'));
    await tester.pump();

    for (final reason in reasons.values) {
      expect(find.text(reason), findsOneWidget, reason: reason);
    }
    expect(saved, isEmpty);
    expect(savedAndPrinted, isEmpty);
  });

  for (final missing in reasons.keys) {
    testWidgets('with only the $missing missing, only its reason shows and nothing is sent', (tester) async {
      await showPage(tester);
      await fill(tester, leaveOut: {missing});

      await tester.tap(find.text('Save box'));
      await tester.pump();

      for (final entry in reasons.entries) {
        expect(
          find.text(entry.value),
          entry.key == missing ? findsOneWidget : findsNothing,
          reason: entry.value,
        );
      }
      expect(saved, isEmpty);
    });
  }

  testWidgets('a reason goes away once its field is filled', (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Save box'));
    await tester.pump();
    expect(find.text(reasons['letter']!), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'a');
    await tester.pump();
    expect(find.text(reasons['letter']!), findsNothing);
  });

  testWidgets('with every required field filled, Save box sends the form once', (tester) async {
    await showPage(tester);
    await fill(tester);

    await tester.tap(find.text('Save box'));
    await tester.pump();

    expect(saved.length, 1);
    expect(savedAndPrinted, isEmpty);
    expect(saved.single.categoryId, 1);
    expect(saved.single.buildingId, 2);
    expect(saved.single.shelfLetter, 'A');
    expect(saved.single.shelfLevel, 2);
    expect(saved.single.fullness, Fullness.full);
    for (final reason in reasons.values) {
      expect(find.text(reason), findsNothing, reason: reason);
    }
  });

  testWidgets('notes are not required', (tester) async {
    await showPage(tester);
    await fill(tester);

    await tester.tap(find.text('Save and print label'));
    await tester.pump();

    expect(savedAndPrinted.length, 1);
    expect(savedAndPrinted.single.notes, isNull);
  });
}
