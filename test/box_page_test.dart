import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/api/api_exception.dart';
import 'package:imp_app/models/box.dart';
import 'package:imp_app/models/box_changes.dart';
import 'package:imp_app/models/building.dart';
import 'package:imp_app/models/category.dart';
import 'package:imp_app/screens/boxes/box_page.dart';
import 'package:imp_app/screens/boxes/sample_box.dart';
import 'package:imp_app/theme.dart';

void main() {
  // What the page handed to its callbacks, so each test can check them.
  late List<BoxChanges> saved;
  late int deletes;

  setUp(() {
    saved = [];
    deletes = 0;
  });

  // The sample box, with any fields changed for one test.
  Box sample([Map<String, dynamic> changes = const {}]) {
    return Box.fromJson({...sampleBox, ...changes});
  }

  BoxPage page(Box box, {Future<void> Function(BoxChanges)? onSave}) {
    return BoxPage(
      box: box,
      categories: [for (final c in sampleCategories) Category.fromJson(c)],
      buildings: [for (final b in sampleBuildings) Building.fromJson(b)],
      onSave: onSave ?? (changes) async => saved.add(changes),
      onDelete: () async => deletes++,
      onPrint: () {},
    );
  }

  // Shows the page on a landscape tablet-sized screen.
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: child));
  }

  // The Save changes button, to check whether it's gray (onPressed is null).
  FilledButton saveButton(WidgetTester tester) {
    return tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes'));
  }

  testWidgets('Save changes stays gray until an edit, and goes gray again when undone', (tester) async {
    await show(tester, page(sample()));
    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Unsaved changes'), findsNothing);

    await tester.tap(find.text('Half'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Full'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Save changes sends every field through onSave, then goes gray', (tester) async {
    await show(tester, page(sample()));
    await tester.tap(find.text('Half'));
    await tester.enterText(find.byType(TextField).last, '  Kids sizes  ');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    final body = saved.single.toJson();
    expect(body['fullness'], 'HALF');
    expect(body['notes'], 'Kids sizes');
    expect(body['categoryId'], 1);
    expect(body['buildingId'], 2);
    expect(body['isRacked'], isTrue);
    expect(body['lastUpdatedAt'], '2026-10-07T18:05:00.000Z');
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('A blank shelf letter shows an error and keeps Save gray', (tester) async {
    await show(tester, page(sample()));
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    expect(find.text('Enter 1 to 3 letters'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'bc');
    await tester.pump();
    expect(find.text('BC'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('A failed save shows the server sentence and keeps the edits', (tester) async {
    await show(
      tester,
      page(sample(), onSave: (_) async {
        throw ApiException('Someone else changed this box. Reload it and make your change again.', screen: 'Box');
      }),
    );
    await tester.tap(find.text('Empty'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Someone else changed this box. Reload it and make your change again.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('Delete popup: Cancel keeps the box, Delete box calls onDelete', (tester) async {
    await show(tester, page(sample()));

    await tester.tap(find.text('Delete box'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Box #6789?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);

    await tester.tap(find.text('Delete box'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete box'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
  });

  testWidgets('Unrack only changes the form', (tester) async {
    await show(tester, page(sample()));
    await tester.tap(find.text('Unrack box'));
    await tester.pump();

    expect(find.text('Re-rack box'), findsOneWidget);
    expect(find.text('Not counted on the dashboard or in alerts'), findsOneWidget);
    expect(saved, isEmpty);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('Re-rack popup: Cancel leaves the box unracked', (tester) async {
    await show(tester, page(sample({'isRacked': false})));
    await tester.tap(find.text('Re-rack box'));
    await tester.pumpAndSettle();
    expect(find.text('Re-rack Box #6789'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Re-rack box'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Re-rack, then Reset to today, is sent on Save', (tester) async {
    await show(tester, page(sample({'isRacked': false})));
    await tester.tap(find.text('Re-rack box'));
    await tester.pumpAndSettle();

    // The popup starts from the box's last location. Change the shelf, then go on.
    final popup = find.byType(Dialog);
    await tester.enterText(find.descendant(of: popup, matching: find.byType(TextField)), 'c');
    await tester.tap(find.descendant(of: popup, matching: find.text('3')));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Reset the storage timer?'), findsOneWidget);
    expect(find.text('Keep 01/14/26'), findsOneWidget);
    await tester.tap(find.text('Reset to today'));
    await tester.pumpAndSettle();

    expect(find.text('Unrack box'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final body = saved.single.toJson();
    expect(body['isRacked'], isTrue);
    expect(body['resetRackedSince'], isTrue);
    expect(body['shelfLetter'], 'C');
    expect(body['shelfLevel'], 3);
  });

  group('Leaving with unsaved changes', () {
    // Opens the Box page on top of a home page, so the back arrow has somewhere to go.
    Future<void> openOverHome(WidgetTester tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(sample()))),
              child: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
    }

    testWidgets('Keep editing stays on the page', (tester) async {
      await openOverHome(tester);
      expect(find.text('Save changes to Box #6789?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Box #6789'), findsOneWidget);
    });

    testWidgets('Discard leaves without saving', (tester) async {
      await openOverHome(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(saved, isEmpty);
    });

    testWidgets('Save saves, then leaves', (tester) async {
      await openOverHome(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(saved.single.toJson()['fullness'], 'HALF');
    });
  });

  testWidgets('With no unsaved changes, the back arrow just leaves', (tester) async {
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(sample()))),
            child: const Text('Home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
