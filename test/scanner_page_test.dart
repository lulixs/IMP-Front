import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/api_scope.dart';
import 'package:imp_app/screens/boxes/sample_box.dart';
import 'package:imp_app/screens/scanner/scanner_page.dart';
import 'package:imp_app/theme.dart';

/// A reply from the fake server. Sent as UTF-8 bytes, since the category symbols are emoji.
http.Response reply(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('boxIdFromCode', () {
    test('reads the box number from a label', () {
      expect(boxIdFromCode('IMP-6789'), 6789);
      expect(boxIdFromCode('IMP-1'), 1);
      expect(boxIdFromCode(' IMP-6789\n'), 6789);
    });

    test('anything else is not a label', () {
      for (final code in ['6789', 'IMP-', 'IMP-67a9', 'imp-6789', 'IMP 6789', 'IMP-6789-2', 'https://example.com', '']) {
        expect(boxIdFromCode(code), isNull, reason: code);
      }
    });
  });

  group('ScannerPage', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    // Every request the fake server got, as "METHOD path"
    late List<String> requests;

    // The fake camera hands its onCode here, so a test can "read" a code
    late void Function(String code) read;

    /// A fake server. boxReply answers GET /api/boxes/{id}.
    MockClient server(http.Response Function() boxReply) {
      return MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return switch (request.url.path) {
          '/api/categories' => reply({'categories': sampleCategories}),
          '/api/buildings' => reply({'buildings': sampleBuildings}),
          _ => boxReply(),
        };
      });
    }

    /// A screen with a Scan button that opens the scanner with a fake camera.
    Future<void> showScanner(WidgetTester tester, http.Client client) async {
      requests = [];
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
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ScannerPage(
                          camera: (context, onCode) {
                            read = onCode;
                            return const ColoredBox(color: Colors.grey);
                          },
                        ),
                      ),
                    ),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
    }

    Future<void> scan(WidgetTester tester, String code) async {
      read(code);
      await tester.pumpAndSettle();
    }

    testWidgets('shows the instructions while scanning', (tester) async {
      await showScanner(tester, server(() => reply(sampleBox)));

      expect(find.text('Scan a box'), findsOneWidget);
      expect(find.text('Point the camera at a box label'), findsOneWidget);
    });

    testWidgets('a box label opens the Box page in place of the scanner', (tester) async {
      await showScanner(tester, server(() => reply(sampleBox)));
      await scan(tester, 'IMP-6789');

      expect(requests, contains('GET /api/boxes/6789'));
      expect(find.text('Box #6789'), findsOneWidget);
      expect(find.text('Scan a box'), findsNothing);

      // Back from the Box page returns to where Scan was tapped, not to the scanner
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a code that is not a label shows 05b without asking the server', (tester) async {
      await showScanner(tester, server(() => reply(sampleBox)));
      await scan(tester, 'https://example.com');

      expect(find.text('No box matches this code'), findsOneWidget);
      expect(requests, isEmpty);
    });

    testWidgets('a box the server does not have shows 05b', (tester) async {
      await showScanner(tester, server(() => reply({'error': "This box doesn't exist."}, 404)));
      await scan(tester, 'IMP-9999');

      expect(requests, ['GET /api/boxes/9999']);
      expect(find.text('No box matches this code'), findsOneWidget);
    });

    testWidgets('a deleted box shows 05c with who deleted it and when', (tester) async {
      await showScanner(
        tester,
        server(() => reply({
              ...sampleBox,
              'id': 6602,
              'deletedAt': '2026-11-20T15:00:00Z',
              'deletedBy': {'id': 4, 'name': 'Grace Kim'},
            })),
      );
      await scan(tester, 'IMP-6602');

      expect(find.text('Box #6602 was deleted'), findsOneWidget);
      expect(find.textContaining('Grace Kim deleted this box on 11/20/26.'), findsOneWidget);
      expect(find.text('Box #6602'), findsNothing);
    });

    testWidgets('a failed load shows the server sentence', (tester) async {
      await showScanner(tester, server(() => reply({'error': 'Something went wrong. Please try again later.'}, 500)));
      await scan(tester, 'IMP-6789');

      expect(find.text("Couldn't open the box"), findsOneWidget);
      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);
    });

    testWidgets('codes read while a sheet shows are ignored, and Scan again starts over', (tester) async {
      await showScanner(tester, server(() => reply(sampleBox)));
      await scan(tester, 'not a label');
      await scan(tester, 'IMP-6789');
      expect(requests, isEmpty);
      expect(find.text('No box matches this code'), findsOneWidget);

      await tester.tap(find.text('Scan again'));
      await tester.pumpAndSettle();
      expect(find.text('Point the camera at a box label'), findsOneWidget);

      await scan(tester, 'IMP-6789');
      expect(find.text('Box #6789'), findsOneWidget);
    });

    testWidgets('Back on a sheet leaves the scanner', (tester) async {
      await showScanner(tester, server(() => reply(sampleBox)));
      await scan(tester, 'not a label');

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
