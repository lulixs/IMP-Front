import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/app_shell.dart';

void main() {
  Future<void> showShell(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const AppShell(active: Section.dashboard, child: Text('Page')),
      ),
    );
  }

  testWidgets('A tablet-sized screen shows the sidebar, the page, and the bottom buttons', (tester) async {
    await showShell(tester, const Size(1024, 768));

    expect(find.text('Page'), findsOneWidget);
    for (final label in ['Dashboard', 'Boxes', 'Categories', 'MASTER ONLY', 'Accounts', 'Audit Log']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(5));
    for (final label in ['Scan', 'Search', 'Alerts']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('A narrow screen moves the sidebar into a drawer', (tester) async {
    await showShell(tester, const Size(400, 800));

    expect(find.text('Boxes'), findsNothing);
    expect(find.text('Scan'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Boxes'), findsOneWidget);
  });
}
