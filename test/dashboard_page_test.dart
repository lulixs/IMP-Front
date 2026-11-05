import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/screens/dashboard/category_card.dart';
import 'package:imp_app/screens/dashboard/dashboard_page.dart';
import 'package:imp_app/theme.dart';

// One category, in the shape from IMP-Back's docs/api/dashboard.md.
const dashboardJson =
    '{"alertThresholdDays":180,"categories":[{"id":1,"name":"Coats","symbol":null,"full":3,"half":2,"empty":1,"storedTooLong":2}]}';

void main() {
  // Some tests fail the load on purpose. This keeps DashboardPage's debugPrint of
  // the error out of the test output. Flutter requires debugPrint to be put back
  // before each test ends, so it is restored here rather than in tearDown.
  Future<void> withoutDebugPrint(Future<void> Function() body) async {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await body();
    } finally {
      debugPrint = original;
    }
  }

  // Shows the dashboard with a fake http client, so no backend is needed.
  Future<void> showPage(
    WidgetTester tester,
    http.Client client, {
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DashboardPage(api: ApiClient(client: client)),
      ),
    );
  }

  testWidgets('Shows a spinner, then one card per category', (tester) async {
    await showPage(
      tester,
      MockClient((request) async => http.Response(dashboardJson, 200)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CategoryCard), findsOneWidget);
    expect(find.text('Coats'), findsOneWidget);
  });

  testWidgets('Shows the error and Try again when the server fails', (
    tester,
  ) async {
    await withoutDebugPrint(() async {
      await showPage(
        tester,
        MockClient((request) async => http.Response('', 500)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load the dashboard"), findsOneWidget);
      expect(find.textContaining('error 500'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  testWidgets('Try again loads the dashboard after a failure', (tester) async {
    await withoutDebugPrint(() async {
      var calls = 0;
      await showPage(
        tester,
        MockClient((request) async {
          calls++;
          return calls == 1
              ? http.Response('', 500)
              : http.Response(dashboardJson, 200);
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byType(CategoryCard), findsOneWidget);
    });
  });

  testWidgets('Data in the wrong shape shows an error instead of crashing', (
    tester,
  ) async {
    await withoutDebugPrint(() async {
      await showPage(
        tester,
        MockClient((request) async => http.Response('{"categories": "oops"}', 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load the dashboard"), findsOneWidget);
      expect(find.text('The dashboard data could not be read.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  testWidgets(
    'A larger system text size makes the card taller instead of overflowing',
    (tester) async {
      await showPage(
        tester,
        MockClient((request) async => http.Response(dashboardJson, 200)),
        textScale: 1.5,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CategoryCard), findsOneWidget);
    },
  );
}
