import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../api/api_scope.dart';
import '../screens/boxes/boxes_screen.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/login/master_login_page.dart';
import '../screens/scanner/scanner_page.dart';
import '../session.dart';
import '../theme.dart';
import 'common.dart';

/// Every page the sidebar can open.
enum Section { dashboard, boxes, categories, accounts, buildings, devices, deleted, audit }

const _mainItems = [
  (Section.dashboard, 'Dashboard', Icons.grid_view_outlined),
  (Section.boxes, 'Boxes', Icons.inventory_2_outlined),
  (Section.categories, 'Categories', Icons.sell_outlined),
];

const _masterItems = [
  (Section.accounts, 'Accounts', Icons.people_outline),
  (Section.buildings, 'Buildings', Icons.apartment_outlined),
  (Section.devices, 'Devices', Icons.tablet_android_outlined),
  (Section.deleted, 'Deleted Items', Icons.delete_outline),
  (Section.audit, 'Audit Log', Icons.description_outlined),
];

/// The frame around the main pages: sidebar on the left, the page in the middle,
/// and the Scan / Search / Alerts bar at the bottom. On narrow screens the sidebar
/// moves into a drawer opened from the top bar.
///
/// The card at the bottom of the sidebar shows who is signed in. Its Master tag turns
/// Master mode on after a popup and a Master sign-in, or off after just the popup, and
/// Switch user goes back to the PIN screen. While Master mode is off, tapping a locked
/// Master-only item opens the same popup. Scan opens the QR scanner. Dashboard and Boxes in the sidebar open
/// their pages, and Search opens Boxes with the search field ready to type in. The other sidebar items and
/// Alerts (week 14) don't do anything yet.
class AppShell extends StatelessWidget {
  /// The route Switch user opens: the employee PIN screen with nothing behind it.
  /// ImpApp registers it, since it knows how to open the dashboard after the next sign-in.
  static const switchUserRoute = '/switch-user';

  /// The current sign-in. Every page gets the same Session and passes it to its
  /// AppShell, so Master mode and the employee's name carry over between pages.
  final Session session;

  /// The sidebar item to highlight.
  final Section active;
  final Widget child;

  const AppShell({super.key, required this.session, required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final sidebar = _Sidebar(session: session, active: active);
    final main = Column(
      children: [
        Expanded(child: child),
        _BottomBar(
          onScan: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScannerPage())),
          onSearch: () => _showSection(context, session, Section.boxes, focusSearch: true),
          // Alerts is built in week 14
        ),
      ],
    );

    if (narrow) {
      return Scaffold(
        backgroundColor: AppColors.card,
        appBar: AppBar(
          backgroundColor: AppColors.panel,
          title: const Text('IMP', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        drawer: Drawer(backgroundColor: AppColors.panel, width: 220, child: SafeArea(child: sidebar)),
        body: main,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(width: 190, child: sidebar),
            Container(width: 2, color: AppColors.barBorder),
            Expanded(child: main),
          ],
        ),
      ),
    );
  }
}

/// Opens a sidebar page in place of the current one, so Back from a box goes to the list and the stack
/// doesn't grow every time the employee switches pages. Only Dashboard and Boxes exist so far.
/// [focusSearch] puts the cursor in the Boxes search field (the Search button).
void _showSection(BuildContext context, Session session, Section section, {bool focusSearch = false}) {
  final api = ApiScope.of(context);
  final navigator = Navigator.of(context);
  final Widget page = switch (section) {
    Section.dashboard => DashboardPage(api: api, session: session),
    Section.boxes => BoxesScreen(api: api, session: session, focusSearch: focusSearch),
    _ => throw ArgumentError('No page for $section yet'),
  };
  // On a narrow screen the sidebar is a drawer, which is a route of its own. Close it first, or it would be
  // the route that gets replaced and the old page would stay underneath.
  if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) navigator.pop();
  navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
}

class _Sidebar extends StatelessWidget {
  final Session session;
  final Section active;
  const _Sidebar({required this.session, required this.active});

  @override
  Widget build(BuildContext context) {
    // Redraws when Master mode is turned on or off.
    return ListenableBuilder(listenable: session, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
      child: Column(
        children: [
          Expanded(child: _navList(context)),
          const SizedBox(height: 8),
          _UserCard(
            session: session,
            onMasterTag: () => _toggleMasterMode(context),
            onSwitchUser: () => _switchUser(context),
          ),
        ],
      ),
    );
  }

  Widget _navList(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Center(child: Logo()),
        const SizedBox(height: 18),
        for (final item in _mainItems) _NavItem(item.$2, item.$3, active: active == item.$1, onTap: _tapFor(context, item.$1)),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 7),
          child: Text(
            'MASTER ONLY',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.ink2),
          ),
        ),
        // Locked while Master mode is off. Tapping a locked one offers to turn Master mode on (D-094).
        for (final item in _masterItems)
          _NavItem(
            item.$2,
            item.$3,
            active: active == item.$1,
            locked: !session.masterMode,
            onTap: session.masterMode ? null : () => _toggleMasterMode(context),
          ),
      ],
    );
  }

  /// What tapping a main item does. Dashboard and Boxes open their pages, and the current page's item just closes
  /// the drawer. Categories isn't built yet.
  VoidCallback? _tapFor(BuildContext context, Section section) {
    if (section != Section.dashboard && section != Section.boxes) return null;
    return () {
      if (section != active) {
        _showSection(context, session, section);
      } else if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    };
  }

  /// Asks first, then turns Master mode the other way, through the server. Turning it on also needs the
  /// Master account to sign in (D-094), and only happens once the server accepts it. Turning it off ends
  /// as soon as the popup is confirmed and the server agrees. Cancel at any step leaves it as it was.
  Future<void> _toggleMasterMode(BuildContext context) async {
    final turnOn = !session.masterMode;
    final confirmed = await showConfirmPopup(
      context,
      title: turnOn ? 'Turn on Master mode?' : 'Turn off Master mode?',
      message: turnOn
          ? 'Master mode unlocks Accounts, Buildings, Devices, Deleted Items, and the Audit Log on this tablet. '
              'You will sign in with the Master account next.'
          : 'Master-only pages lock again on this tablet.',
      confirmLabel: turnOn ? 'Turn on' : 'Turn off',
    );
    if (!confirmed) return;
    if (!turnOn) {
      try {
        await session.turnOffMasterMode();
      } on ApiException catch (e) {
        // Master mode stays on, and the bar at the bottom says why.
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!context.mounted) return;

    // Session turns Master mode on once the server accepts the sign-in, and the screen closes itself.
    // A refused sign-in shows the server's sentence there. Cancel or the back button leave it off.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => MasterLoginPage(
          mode: MasterLoginMode.masterToggle,
          onSignIn: (email, password, _) async {
            final error = await session.turnOnMasterMode(email, password);
            if (error == null && pageContext.mounted) Navigator.of(pageContext).pop();
            return error;
          },
        ),
      ),
    );
  }

  /// Signs the employee out on the server, then closes every page, which throws away this Session, and
  /// opens the PIN screen. The next sign-in makes a new Session, so Master mode starts off again. If signing
  /// out fails, it stays put and the bar at the bottom says why.
  Future<void> _switchUser(BuildContext context) async {
    try {
      await session.signOut();
    } on ApiException catch (e) {
      if (e.code == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppShell.switchUserRoute, (_) => false);
    }
  }
}

/// The card at the bottom of the sidebar: the Master tag, then the signed-in employee and Switch user.
class _UserCard extends StatelessWidget {
  final Session session;
  final VoidCallback onMasterTag;
  final VoidCallback onSwitchUser;
  const _UserCard({required this.session, required this.onMasterTag, required this.onSwitchUser});

  @override
  Widget build(BuildContext context) {
    final on = session.masterMode;
    final tagColor = on ? Colors.white : AppColors.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Black when Master mode is on, white when it is off.
          Material(
            color: on ? AppColors.ink : AppColors.card,
            shape: const StadiumBorder(side: BorderSide(color: AppColors.ink, width: 1.5)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onMasterTag,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 5, 9, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible lets the label wrap instead of overflowing when the system text size is large.
                    Flexible(
                      child: Text(
                        on ? 'Master on' : 'Master off',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tagColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.sync, size: 14, color: tagColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Avatar(session.employeeName),
          const SizedBox(height: 7),
          Text(
            session.employeeName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: onSwitchUser,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.card,
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 13.5),
              ),
              child: const Text('Switch user'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool locked;

  /// Makes the item a button. Null for items that don't do anything yet.
  final VoidCallback? onTap;

  const _NavItem(this.label, this.icon, {required this.active, this.locked = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : (locked ? AppColors.ink3 : AppColors.ink);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: active ? AppColors.ink : (locked ? Colors.transparent : AppColors.card),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: active ? AppColors.ink : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (locked) Icon(Icons.lock_outline, size: 13, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  /// Null for buttons that don't do anything yet.
  final VoidCallback? onScan;
  final VoidCallback? onSearch;
  final VoidCallback? onAlerts;

  const _BottomBar({this.onScan, this.onSearch, this.onAlerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: AppColors.soft,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomButton(Icons.qr_code_scanner, 'Scan', onTap: onScan),
          _BottomButton(Icons.search, 'Search', onTap: onSearch),
          _BottomButton(Icons.notifications_none, 'Alerts', onTap: onAlerts),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Null for buttons that don't do anything yet.
  final VoidCallback? onTap;
  const _BottomButton(this.icon, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: AppColors.ink),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
