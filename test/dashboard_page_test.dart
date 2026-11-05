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
  // Shows the dashboard with a fake http client, so no backend is needed.
  Future<void> showPage(WidgetTester tester, http.Client client) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
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
    expect(find.text('SAMPLE'), findsNothing);
  });

  testWidgets('Shows the error and Try again when the server fails', (
    tester,
  ) async {
    await showPage(
      tester,
      MockClient((request) async => http.Response('', 500)),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load the dashboard"), findsOneWidget);
    expect(find.textContaining('error 500'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Try again loads the dashboard after a failure', (tester) async {
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
}
