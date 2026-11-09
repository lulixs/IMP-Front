import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/session.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/app_shell.dart';

void main() {
  final locks = find.byIcon(Icons.lock_outline);

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> showShell(WidgetTester tester, Size size) {
    setSize(tester, size);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AppShell(
          session: Session(employeeName: 'Dan Finkle'),
          active: Section.dashboard,
          child: const Text('Page'),
        ),
      ),
    );
  }

  testWidgets('A tablet-sized screen shows the sidebar, the page, and the bottom buttons', (tester) async {
    await showShell(tester, const Size(1024, 768));

    expect(find.text('Page'), findsOneWidget);
    for (final label in ['Dashboard', 'Boxes', 'Categories', 'MASTER ONLY', 'Accounts', 'Audit Log']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(locks, findsNWidgets(5), reason: 'Master mode starts off, so the Master-only items are locked');
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

  testWidgets('Master mode turned on in one AppShell stays on in the next AppShell', (tester) async {
    setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: _TestPage(Session(employeeName: 'Dan Finkle'), Section.dashboard)),
    );
    final first = tester.widget<AppShell>(find.byType(AppShell));
    expect(first.session.masterMode, isFalse);
    expect(locks, findsNWidgets(5));

    // Turn Master mode on in the first AppShell. Its sidebar unlocks straight away.
    first.session.masterMode = true;
    await tester.pump();
    expect(locks, findsNothing);

    // Open a second page, which makes a second AppShell.
    await tester.tap(find.text('Open the Boxes page'));
    await tester.pumpAndSettle();
    expect(find.text('Page: boxes'), findsOneWidget);

    // Only the second AppShell is on screen now. It has the same session, and Master mode is still on.
    final second = tester.widget<AppShell>(find.byType(AppShell));
    expect(second, isNot(same(first)));
    expect(second.session, same(first.session));
    expect(second.session.masterMode, isTrue);
    expect(locks, findsNothing);
  });
}

/// Stands in for a real page: builds an AppShell with the session it was given, and has a
/// button that opens the next page with that same session, the way real pages will.
class _TestPage extends StatelessWidget {
  final Session session;
  final Section section;
  const _TestPage(this.session, this.section);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      session: session,
      active: section,
      child: Column(
        children: [
          Text('Page: ${section.name}'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _TestPage(session, Section.boxes)),
            ),
            child: const Text('Open the Boxes page'),
          ),
        ],
      ),
    );
  }
}
