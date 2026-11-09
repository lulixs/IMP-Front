import 'package:flutter/material.dart';

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
/// Master mode on or off after a popup, and Switch user goes back to the PIN screen.
/// The sidebar items and bottom buttons don't do anything yet.
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
        const _BottomBar(),
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
          Expanded(child: _navList()),
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

  Widget _navList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Center(child: Logo()),
        const SizedBox(height: 18),
        for (final item in _mainItems) _NavItem(item.$2, item.$3, active: active == item.$1),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 7),
          child: Text(
            'MASTER ONLY',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.ink2),
          ),
        ),
        // Locked while Master mode is off.
        for (final item in _masterItems)
          _NavItem(item.$2, item.$3, active: active == item.$1, locked: !session.masterMode),
      ],
    );
  }

  /// Asks first, then turns Master mode the other way. Cancel leaves it as it was.
  Future<void> _toggleMasterMode(BuildContext context) async {
    final turnOn = !session.masterMode;
    final confirmed = await showConfirmPopup(
      context,
      title: turnOn ? 'Turn on Master mode?' : 'Turn off Master mode?',
      message: turnOn
          ? 'Master mode unlocks Accounts, Buildings, Devices, Deleted Items, and the Audit Log on this tablet.'
          : 'Master-only pages lock again on this tablet.',
      confirmLabel: turnOn ? 'Turn on' : 'Turn off',
    );
    if (confirmed) session.masterMode = turnOn;
  }

  /// Signs the employee out: every page is closed, which throws away this Session, and the
  /// PIN screen opens. The next sign-in makes a new Session, so Master mode starts off again.
  void _switchUser(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(AppShell.switchUserRoute, (_) => false);
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
  const _NavItem(this.label, this.icon, {required this.active, this.locked = false});

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
                    style: TextStyle(fontSize: 14, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w400),
                  ),
                ),
                if (locked) Icon(Icons.lock_outline, size: 13, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: AppColors.soft,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomButton(Icons.qr_code_scanner, 'Scan'),
          _BottomButton(Icons.search, 'Search'),
          _BottomButton(Icons.notifications_none, 'Alerts'),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BottomButton(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppColors.ink),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
