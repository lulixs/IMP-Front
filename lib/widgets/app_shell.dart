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
/// The sidebar items and bottom buttons don't do anything yet.
class AppShell extends StatelessWidget {
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
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
