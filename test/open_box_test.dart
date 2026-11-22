import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_scope.dart';
import 'package:imp_app/screens/boxes/open_box.dart';
import 'package:imp_app/screens/boxes/sample_box.dart';
import 'package:imp_app/theme.dart';

/// A reply from the fake server. Sent as UTF-8 bytes, since the category symbols are emoji.
http.Response reply(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// The sample box in the shape from IMP-Back's docs/api/boxes.md, with any fields changed for one test.
Map<String, dynamic> boxJson([Map<String, dynamic> changes = const {}]) => {...sampleBox, ...changes};

/// What the fake server answers for the two dropdown lists.
http.Response? lists(http.Request request) {
  return switch (request.url.path) {
    '/api/categories' => reply({'categories': sampleCategories}),
    '/api/buildings' => reply({'buildings': sampleBuildings}),
    _ => null,
  };
}

void main() {
  // ApiClient reads tokens from locked storage, which tests don't have. This swaps in an empty stand-in.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // Every request the fake server got, as "METHOD path", and the body of each PUT
  late List<String> requests;
  late List<Map<String, dynamic>> putBodies;

  setUp(() {
    requests = [];
    putBodies = [];
  });

  /// A fake server. handle answers the box requests, and the lists are answered for every test.
  MockClient server(FutureOr<http.Response> Function(http.Request request) handle) {
    return MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'PUT') putBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return lists(request) ?? await handle(request);
    });
  }

  // What the last openBox returned
  OpenBoxResult? result;

  /// A screen with an Open button that calls openBox for box 6789, on a landscape tablet-sized screen.
  Future<void> showHost(WidgetTester tester, http.Client client) async {
    result = null;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ApiScope(
        api: ApiClient(client: client),
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => result = await openBox(context, 6789),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) {
    return tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes'));
  }

  group('openBox', () {
    testWidgets('shows a loading wheel, then opens the Box page with the box from the server', (tester) async {
      final box = Completer<http.Response>();
      await showHost(tester, server((request) => box.future));

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Box #6789'), findsNothing);

      box.complete(reply(boxJson()));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Box #6789'), findsOneWidget);
      expect(requests, containsAll(['GET /api/boxes/6789', 'GET /api/categories', 'GET /api/buildings']));
    });

    testWidgets('fills the dropdowns from the server', (tester) async {
      await showHost(tester, server((request) => reply(boxJson())));
      await open(tester);

      await tester.tap(find.text('🧥 Coats'));
      await tester.pumpAndSettle();
      expect(find.text('🎄 Christmas'), findsWidgets);
    });

    testWidgets('a deleted box does not open the Box page', (tester) async {
      await showHost(
        tester,
        server((request) => reply(boxJson({
              'deletedAt': '2026-11-20T15:00:00Z',
              'deletedBy': {'id': 4, 'name': 'Grace Kim'},
            }))),
      );
      await open(tester);

      expect(find.text('Box #6789'), findsNothing);
      expect(find.text('Box #6789 was deleted.'), findsOneWidget);
      expect(result, isA<BoxWasDeleted>());
      expect((result as BoxWasDeleted).box.deletedBy!.name, 'Grace Kim');
      // The lists are only loaded for a box that opens
      expect(requests, ['GET /api/boxes/6789']);
    });

    testWidgets('a missing box shows the server sentence', (tester) async {
      await showHost(tester, server((request) => reply({'error': "This box doesn't exist."}, 404)));
      await open(tester);

      expect(find.text("This box doesn't exist."), findsOneWidget);
      expect(result, isA<BoxNotFound>());
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a failed load shows the server sentence and closes the wheel', (tester) async {
      await showHost(tester, server((request) => reply({'error': 'Something went wrong. Please try again later.'}, 500)));
      await open(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);
      expect(result, isA<BoxLoadFailed>());
    });

    testWidgets('completes with BoxOpened once the Box page closes', (tester) async {
      await showHost(tester, server((request) => reply(boxJson())));
      await open(tester);
      expect(result, isNull);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(result, isA<BoxOpened>());
    });
  });

  group('Box page on the server', () {
    // A box saved by Noah at noon UTC, the same date in any US time zone
    final savedByNoah = boxJson({
      'fullness': 'HALF',
      'lastUpdatedAt': '2026-11-21T12:00:00Z',
      'lastUpdatedBy': {'id': 2, 'name': 'Noah Pragle'},
    });

    testWidgets('Save changes sends every field and the lastUpdatedAt it loaded, then shows the saved box',
        (tester) async {
      await showHost(tester, server((request) => request.method == 'PUT' ? reply(savedByNoah) : reply(boxJson())));
      await open(tester);

      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(requests, contains('PUT /api/boxes/6789'));
      expect(putBodies.single, {
        'categoryId': 1,
        'buildingId': 2,
        'shelfLetter': 'A',
        'shelfLevel': 2,
        'fullness': 'HALF',
        'notes': 'Mostly adult sizes. Check zippers before putting out.',
        'isRacked': true,
        'resetRackedSince': false,
        'lastUpdatedAt': '2026-10-07T18:05:00.000Z',
      });
      expect(find.text('Last edited 11/21/26 by Noah Pragle'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('the next save sends the lastUpdatedAt from the last save', (tester) async {
      await showHost(tester, server((request) => request.method == 'PUT' ? reply(savedByNoah) : reply(boxJson())));
      await open(tester);

      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empty'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(putBodies, hasLength(2));
      expect(putBodies.last['lastUpdatedAt'], '2026-11-21T12:00:00.000Z');
    });

    testWidgets('on 409 it shows the server sentence and reloads the box', (tester) async {
      // Grace saved the box on another tablet after this one loaded it
      var current = boxJson();
      await showHost(
        tester,
        server((request) {
          if (request.method == 'PUT') {
            return reply({'error': 'Someone else changed this box. Reload it and make your change again.'}, 409);
          }
          return reply(current);
        }),
      );
      await open(tester);
      current = boxJson({
        'fullness': 'EMPTY',
        'lastUpdatedAt': '2026-11-21T12:00:00Z',
        'lastUpdatedBy': {'id': 4, 'name': 'Grace Kim'},
      });

      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Someone else changed this box. Reload it and make your change again.'), findsOneWidget);
      expect(requests.where((r) => r == 'GET /api/boxes/6789'), hasLength(2));
      // Still on the Box page, now showing Grace's save, with nothing left to save
      expect(find.text('Box #6789'), findsOneWidget);
      expect(find.text('Last edited 11/21/26 by Grace Kim'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('on 404 it goes back and shows the server sentence', (tester) async {
      await showHost(
        tester,
        server((request) => request.method == 'PUT' ? reply({'error': 'This box was deleted.'}, 404) : reply(boxJson())),
      );
      await open(tester);

      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Box #6789'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('This box was deleted.'), findsOneWidget);
    });

    testWidgets('Delete box sends DELETE and goes back', (tester) async {
      await showHost(
        tester,
        server((request) => request.method == 'DELETE' ? http.Response('', 204) : reply(boxJson())),
      );
      await open(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete box'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete box'));
      await tester.pumpAndSettle();

      expect(requests, contains('DELETE /api/boxes/6789'));
      expect(find.text('Box #6789'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a refused delete keeps the page and shows the server sentence', (tester) async {
      await showHost(
        tester,
        server((request) => request.method == 'DELETE'
            ? reply({'error': 'Something went wrong. Please try again later.'}, 500)
            : reply(boxJson())),
      );
      await open(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete box'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete box'));
      await tester.pumpAndSettle();

      expect(find.text('Box #6789'), findsOneWidget);
      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);
    });

    testWidgets('shows a loading wheel while saving', (tester) async {
      final saved = Completer<http.Response>();
      await showHost(tester, server((request) => request.method == 'PUT' ? saved.future : reply(boxJson())));
      await open(tester);

      await tester.tap(find.text('Half'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      saved.complete(reply(savedByNoah));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
