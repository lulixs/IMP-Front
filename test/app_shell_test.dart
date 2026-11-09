import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/session.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/app_shell.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  final locks = find.byIcon(Icons.lock_outline);

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Shows [_TestPage] with a new session. Switch user lands on a stand-in for the PIN screen.
  Future<Session> showPage(WidgetTester tester, {Size size = const Size(1024, 768)}) async {
    setSize(tester, size);
    final session = Session(employeeName: 'Dan Finkle');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        routes: {AppShell.switchUserRoute: (_) => const Text('PIN screen')},
        home: _TestPage(session, Section.dashboard),
      ),
    );
    return session;
  }

  /// Taps the Master tag and answers the popup.
  Future<void> answerMasterPopup(WidgetTester tester, {required String tag, required String answer}) async {
    await tap(tester, find.text(tag));
    await tap(tester, find.text(answer));
  }

  testWidgets('A tablet-sized screen shows the sidebar, the page, and the bottom buttons', (tester) async {
    await showPage(tester);

    expect(find.text('Page: dashboard'), findsOneWidget);
    for (final label in ['Dashboard', 'Boxes', 'Categories', 'MASTER ONLY', 'Accounts', 'Audit Log']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(locks, findsNWidgets(5), reason: 'Master mode starts off, so the Master-only items are locked');
    for (final label in ['Scan', 'Search', 'Alerts']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('The sidebar card shows the Master tag, the employee, and Switch user', (tester) async {
    await showPage(tester);

    expect(find.text('Master off'), findsOneWidget);
    expect(find.text('Dan Finkle'), findsOneWidget);
    expect(find.widgetWithText(Avatar, 'D'), findsOneWidget);
    expect(find.text('Switch user'), findsOneWidget);
  });

  testWidgets('A narrow screen moves the sidebar, card included, into a drawer', (tester) async {
    await showPage(tester, size: const Size(400, 800));

    expect(find.text('Boxes'), findsNothing);
    expect(find.text('Switch user'), findsNothing);
    expect(find.text('Scan'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Boxes'), findsOneWidget);
    expect(find.text('Switch user'), findsOneWidget);
  });

  testWidgets('The Master tag asks before turning Master mode on, and Cancel changes nothing', (tester) async {
    final session = await showPage(tester);

    await tap(tester, find.text('Master off'));
    expect(find.text('Turn on Master mode?'), findsOneWidget);

    await tap(tester, find.text('Cancel'));
    expect(find.text('Turn on Master mode?'), findsNothing);
    expect(session.masterMode, isFalse);
    expect(find.text('Master off'), findsOneWidget);
    expect(locks, findsNWidgets(5));
  });

  testWidgets('Turning Master mode on and off flips the tag and the lock icons', (tester) async {
    final session = await showPage(tester);

    await answerMasterPopup(tester, tag: 'Master off', answer: 'Turn on');
    expect(session.masterMode, isTrue);
    expect(find.text('Master on'), findsOneWidget);
    expect(locks, findsNothing);

    await tap(tester, find.text('Master on'));
    expect(find.text('Turn off Master mode?'), findsOneWidget);
    await tap(tester, find.text('Turn off'));
    expect(session.masterMode, isFalse);
    expect(find.text('Master off'), findsOneWidget);
    expect(locks, findsNWidgets(5));
  });

  testWidgets('Master mode turned on in one AppShell stays on in the next AppShell', (tester) async {
    await showPage(tester);
    final first = tester.widget<AppShell>(find.byType(AppShell));

    // Turn Master mode on in the first AppShell, through the Master tag and its popup.
    await answerMasterPopup(tester, tag: 'Master off', answer: 'Turn on');
    expect(locks, findsNothing);

    // Open a second page, which makes a second AppShell.
    await tap(tester, find.text('Open the Boxes page'));
    expect(find.text('Page: boxes'), findsOneWidget);

    // Only the second AppShell is on screen now. It has the same session, and Master mode is still on.
    final second = tester.widget<AppShell>(find.byType(AppShell));
    expect(second, isNot(same(first)));
    expect(second.session, same(first.session));
    expect(second.session.masterMode, isTrue);
    expect(find.text('Master on'), findsOneWidget);
    expect(locks, findsNothing);
  });

  testWidgets('Switch user closes every page and opens the PIN screen with nothing behind it', (tester) async {
    await showPage(tester);
    await tap(tester, find.text('Open the Boxes page'));

    await tap(tester, find.text('Switch user'));

    expect(find.text('PIN screen'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(AppShell, skipOffstage: false), findsNothing, reason: 'no page is left behind it');
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
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
