import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:imp_app/api/api_client.dart';
import 'package:imp_app/api/auth_api.dart';
import 'package:imp_app/api/token_store.dart';
import 'package:imp_app/screens/login/master_login_page.dart';
import 'package:imp_app/session.dart';
import 'package:imp_app/theme.dart';
import 'package:imp_app/widgets/app_shell.dart';
import 'package:imp_app/widgets/common.dart';

void main() {
  final locks = find.byIcon(Icons.lock_outline);

  // The Master password the fake server accepts. Any other is refused, like the real one.
  const masterPassword = 'master123';
  const wrongPassword = 'wrong';

  // Every request the fake server got, as "METHOD path"
  late List<String> requests;

  // The tablet is signed in, so Switch user has a session to forget.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(
        {'deviceToken': 'device-abc', 'sessionToken': 'session-xyz', 'employeeId': '1', 'employeeName': 'Dan Finkle'});
    requests = [];
  });

  // A fake server for Master mode and sign-out. Tests pass a reply to make one of them fail.
  MockClient server({http.Response? masterModeOff, http.Response? signOut}) {
    return MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return switch ('${request.method} ${request.url.path}') {
        'POST /api/master-mode' => request.body.contains('"password":"$masterPassword"')
            ? http.Response('', 204)
            : http.Response('{"error": "Incorrect email or password. Try again."}', 401),
        'DELETE /api/master-mode' => masterModeOff ?? http.Response('', 204),
        'DELETE /api/sessions/current' => signOut ?? http.Response('', 204),
        _ => http.Response('{"error": "This address doesn\'t exist on the server."}', 404),
      };
    });
  }

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

  /// Shows [_TestPage] with a new session on [client], or a fake server where everything works. Switch user
  /// lands on a stand-in for the PIN screen.
  Future<Session> showPage(WidgetTester tester, {Size size = const Size(1024, 768), MockClient? client}) async {
    setSize(tester, size);
    final session = Session(employeeId: 1, employeeName: 'Dan Finkle', auth: AuthApi(ApiClient(client: client ?? server())));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        routes: {AppShell.switchUserRoute: (_) => const Text('PIN screen')},
        home: _TestPage(session, Section.dashboard),
      ),
    );
    return session;
  }

  /// Signs in on the Master sign-in screen. The fake server accepts only [masterPassword].
  Future<void> signInMaster(WidgetTester tester, {String password = masterPassword}) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'store@example.org');
    await tester.enterText(fields.at(1), password);
    await tap(tester, find.widgetWithText(FilledButton, 'Sign In'));
  }

  /// Taps [start] (the Master tag or a locked item), answers the popup with [answer], then signs in.
  Future<void> toggleMasterMode(WidgetTester tester, {required String start, required String answer}) async {
    await tap(tester, find.text(start));
    await tap(tester, find.text(answer));
    await signInMaster(tester);
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

  testWidgets('After the popup, the Master sign-in screen opens', (tester) async {
    final session = await showPage(tester);

    await tap(tester, find.text('Master off'));
    await tap(tester, find.text('Turn on'));

    final page = tester.widget<MasterLoginPage>(find.byType(MasterLoginPage));
    expect(page.mode, MasterLoginMode.masterToggle);
    expect(find.text('Activate Master Mode'), findsOneWidget);
    expect(session.masterMode, isFalse, reason: 'nothing changes until the Master account signs in');
  });

  testWidgets('Cancel on the Master sign-in screen changes nothing', (tester) async {
    final session = await showPage(tester);
    await tap(tester, find.text('Master off'));
    await tap(tester, find.text('Turn on'));

    await tap(tester, find.widgetWithText(OutlinedButton, 'Cancel'));

    expect(find.byType(MasterLoginPage), findsNothing);
    expect(session.masterMode, isFalse);
    expect(find.text('Master off'), findsOneWidget);
    expect(locks, findsNWidgets(5));
  });

  testWidgets('A wrong Master password shows the error and keeps Master mode off', (tester) async {
    final session = await showPage(tester);
    await tap(tester, find.text('Master off'));
    await tap(tester, find.text('Turn on'));

    await signInMaster(tester, password: wrongPassword);

    expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
    expect(find.byType(MasterLoginPage), findsOneWidget);
    expect(session.masterMode, isFalse);
    expect(requests, ['POST /api/master-mode'], reason: 'the server checked the password');
  });

  testWidgets('Turning Master mode on needs the sign-in, turning it off only the popup', (tester) async {
    final session = await showPage(tester);

    await toggleMasterMode(tester, start: 'Master off', answer: 'Turn on');
    expect(find.byType(MasterLoginPage), findsNothing);
    expect(session.masterMode, isTrue);
    expect(find.text('Master on'), findsOneWidget);
    expect(locks, findsNothing);

    await tap(tester, find.text('Master on'));
    expect(find.text('Turn off Master mode?'), findsOneWidget);
    await tap(tester, find.text('Turn off'));
    expect(find.byType(MasterLoginPage), findsNothing, reason: 'turning it off just logs out of Master mode');
    expect(session.masterMode, isFalse);
    expect(find.text('Master off'), findsOneWidget);
    expect(locks, findsNWidgets(5));
  });

  testWidgets('Cancel on the turn-off popup keeps Master mode on', (tester) async {
    final session = await showPage(tester);
    await toggleMasterMode(tester, start: 'Master off', answer: 'Turn on');

    await tap(tester, find.text('Master on'));
    await tap(tester, find.text('Cancel'));

    expect(session.masterMode, isTrue);
    expect(find.text('Master on'), findsOneWidget);
    expect(locks, findsNothing);
  });

  testWidgets('Tapping a locked Master-only item opens the same popup', (tester) async {
    final session = await showPage(tester);

    for (final label in ['Accounts', 'Buildings', 'Devices', 'Deleted Items', 'Audit Log']) {
      await tap(tester, find.text(label));
      expect(find.text('Turn on Master mode?'), findsOneWidget, reason: label);
      await tap(tester, find.text('Cancel'));
    }

    await toggleMasterMode(tester, start: 'Accounts', answer: 'Turn on');
    expect(session.masterMode, isTrue);

    // Unlocked, the items don't open anything yet, and certainly not the popup.
    await tap(tester, find.text('Accounts'));
    expect(find.text('Turn off Master mode?'), findsNothing);
    expect(find.text('Turn on Master mode?'), findsNothing);
  });

  testWidgets('Master mode turned on in one AppShell stays on in the next AppShell', (tester) async {
    await showPage(tester);
    final first = tester.widget<AppShell>(find.byType(AppShell));

    // Turn Master mode on in the first AppShell, through the Master tag, its popup, and the sign-in.
    await toggleMasterMode(tester, start: 'Master off', answer: 'Turn on');
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

  group('Through the server', () {
    testWidgets('Turning Master mode on and off tells the server each time', (tester) async {
      await showPage(tester);

      await toggleMasterMode(tester, start: 'Master off', answer: 'Turn on');
      await tap(tester, find.text('Master on'));
      await tap(tester, find.text('Turn off'));

      expect(requests, ['POST /api/master-mode', 'DELETE /api/master-mode']);
    });

    testWidgets('If the server can\'t turn Master mode off, it stays on and the bar says why', (tester) async {
      final session = await showPage(
        tester,
        client: server(masterModeOff: http.Response('{"error": "Something went wrong. Please try again later."}', 500)),
      );
      await toggleMasterMode(tester, start: 'Master off', answer: 'Turn on');

      await tap(tester, find.text('Master on'));
      await tap(tester, find.text('Turn off'));

      expect(session.masterMode, isTrue);
      expect(find.text('Master on'), findsOneWidget);
      expect(locks, findsNothing);
      expect(find.widgetWithText(SnackBar, 'Something went wrong. Please try again later.'), findsOneWidget);
    });

    testWidgets('Switch user signs out on the server and forgets the saved session', (tester) async {
      await showPage(tester);

      await tap(tester, find.text('Switch user'));

      expect(requests, ['DELETE /api/sessions/current']);
      final tokens = TokenStore();
      expect(await tokens.readSessionToken(), isNull);
      expect(await tokens.readEmployee(), isNull);
      expect(await tokens.readDeviceToken(), 'device-abc', reason: 'the tablet stays set up');
    });

    testWidgets('If signing out fails, Switch user stays on the page and the bar says why', (tester) async {
      await showPage(
        tester,
        client: server(signOut: http.Response('{"error": "Something went wrong. Please try again later."}', 500)),
      );

      await tap(tester, find.text('Switch user'));

      expect(find.text('PIN screen'), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.widgetWithText(SnackBar, 'Something went wrong. Please try again later.'), findsOneWidget);
      expect(await TokenStore().readSessionToken(), 'session-xyz');
    });

    testWidgets('A session that already ended shows no bar, since ApiClient handles sessionEnded', (tester) async {
      await showPage(
        tester,
        client: server(
          signOut: http.Response('{"error": "You\'ve been signed out. Sign in again.", "code": "sessionEnded"}', 401),
        ),
      );

      await tap(tester, find.text('Switch user'));

      expect(find.byType(SnackBar), findsNothing);
      expect(await TokenStore().readSessionToken(), isNull);
    });
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
