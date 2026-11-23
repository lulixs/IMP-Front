import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/box.dart';
import '../../models/box_query.dart';
import '../../models/category.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Boxes list (wireframe 04): search, three filters, and one row per box.
///
/// The page owns what is typed and chosen, and the 300 ms wait after typing. It does not talk to the server:
/// [onQueryChanged] is called with the new [BoxQuery], and Connect (BoxesScreen) sends `GET /api/boxes` and
/// hands back [boxes]. Typing waits 300 ms after the last key. A filter change asks right away.
class BoxesPage extends StatefulWidget {
  /// For the category filter. Empty until they have loaded.
  final List<Category> categories;

  /// True when the Search button opened this page, so the search field is ready to type in.
  final bool focusSearch;

  /// The latest answer from the server, or null before the first one arrives.
  final List<Box>? boxes;

  /// True while a request is out. The old rows stay until the new ones arrive.
  final bool loading;

  /// The server's sentence when the last request failed, or null.
  final String? error;

  /// Called with the search and filters, 300 ms after typing stops and again on each filter change.
  final void Function(BoxQuery query) onQueryChanged;

  /// Called when a row is tapped. Connect calls openBox.
  final void Function(Box box) onOpenBox;

  /// Called when the round + button is tapped. Connect opens New Box.
  final VoidCallback onNewBox;

  /// Called by "Try again" under an error.
  final VoidCallback onRetry;

  const BoxesPage({
    super.key,
    this.focusSearch = false,
    required this.categories,
    required this.boxes,
    required this.loading,
    required this.error,
    required this.onQueryChanged,
    required this.onOpenBox,
    required this.onNewBox,
    required this.onRetry,
  });

  @override
  State<BoxesPage> createState() => _BoxesPageState();
}

class _BoxesPageState extends State<BoxesPage> {
  static const _typingWait = Duration(milliseconds: 300);

  // Dropdown value for "All categories". Real category ids start at 1.
  static const _allCategories = 0;

  final _search = TextEditingController();
  Timer? _timer;

  // What the filters show right now, and the last thing sent to Connect
  BoxQuery _query = const BoxQuery();
  BoxQuery _sent = const BoxQuery();

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Each keystroke restarts the wait, so only a pause in typing asks the server
  void _onTyped(String text) {
    _query = _query.copyWith(search: text);
    _timer?.cancel();
    _timer = Timer(_typingWait, _send);
  }

  // A filter was changed: ask now, and drop any wait still running from typing
  void _onFilter(BoxQuery query) {
    setState(() => _query = query);
    _timer?.cancel();
    _send();
  }

  void _send() {
    if (_query == _sent) return;
    _sent = _query;
    widget.onQueryChanged(_query);
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold of its own: AppShell (sidebar and bottom bar) is the frame, like the dashboard
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        _filters(),
        // A thin bar while the server answers, without clearing the rows
        SizedBox(height: 3, child: widget.loading ? const LinearProgressIndicator(minHeight: 3) : null),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Boxes', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_subtitle(), style: const TextStyle(fontSize: 14, color: AppColors.ink2)),
              ],
            ),
          ),
          // The round + button
          IconButton.filled(
            tooltip: 'New box',
            iconSize: 30,
            style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            onPressed: widget.onNewBox,
          ),
        ],
      ),
    );
  }

  // "Coats: 6 racked boxes, plus 1 unracked", worked out from the rows on screen
  String _subtitle() {
    final boxes = widget.boxes;
    if (boxes == null) return '';

    String count(int n, String word) => '$n $word box${n == 1 ? '' : 'es'}';
    final racked = boxes.where((b) => b.isRacked).length;
    final unracked = boxes.length - racked;

    final String what;
    switch (_query.rack) {
      case RackFilter.racked:
        what = count(racked, 'racked');
      case RackFilter.unracked:
        what = count(unracked, 'unracked');
      case RackFilter.all:
        what = unracked == 0 ? count(racked, 'racked') : '${count(racked, 'racked')}, plus $unracked unracked';
    }

    final id = _query.categoryId;
    final named = widget.categories.where((c) => c.id == id);
    final who = named.isNotEmpty
        ? named.first.name
        : (_query.search.trim().isEmpty ? 'All categories' : 'Matching boxes');
    return '$who: $what';
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _search,
              autofocus: widget.focusSearch,
              onChanged: _onTyped,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Category name or box ID…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _query.categoryId ?? _allCategories,
              items: [
                const DropdownMenuItem(value: _allCategories, child: Text('All categories')),
                for (final c in widget.categories)
                  DropdownMenuItem(value: c.id, child: Text(c.symbol == null ? c.name : '${c.symbol} ${c.name}')),
              ],
              onChanged: (id) => _onFilter(
                _query.copyWith(categoryId: (id == null || id == _allCategories ? null : id,)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<RackFilter>(
              isExpanded: true,
              initialValue: _query.rack,
              items: const [
                DropdownMenuItem(value: RackFilter.all, child: Text('Rack: All')),
                DropdownMenuItem(value: RackFilter.racked, child: Text('Rack: Racked')),
                DropdownMenuItem(value: RackFilter.unracked, child: Text('Rack: Unracked')),
              ],
              onChanged: (rack) => _onFilter(_query.copyWith(rack: rack)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<BoxSort>(
              isExpanded: true,
              initialValue: _query.sort,
              items: const [
                DropdownMenuItem(value: BoxSort.oldest, child: Text('Oldest first')),
                DropdownMenuItem(value: BoxSort.newest, child: Text('Newest first')),
              ],
              onChanged: (sort) => _onFilter(_query.copyWith(sort: sort)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final boxes = widget.boxes;

    if (widget.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          ErrorBox(widget.error!),
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton('Try again', expand: false, onPressed: widget.onRetry),
          ),
        ],
      );
    }

    // Nothing has arrived yet. The wheel only spins while a request is out: after a sign-in problem
    // (no sentence to show, since ApiClient opened another screen) nothing is coming, so nothing spins.
    if (boxes == null) {
      return widget.loading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    }

    if (boxes.isEmpty) {
      return const Center(
        child: Text('No boxes match.', style: TextStyle(fontSize: 16, color: AppColors.ink2)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      itemCount: boxes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _BoxRow(box: boxes[i], onTap: () => widget.onOpenBox(boxes[i])),
    );
  }
}

/// One box in the list: number, category, and the Unracked tag on the left; where it is on the second line;
/// days stored and the fullness bar on the right.
class _BoxRow extends StatelessWidget {
  final Box box;
  final VoidCallback onTap;

  const _BoxRow({required this.box, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = box.daysStored;
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row, so a long category name moves the tag down instead of running off the row
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Box #${box.id}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(box.category.name, style: const TextStyle(fontSize: 16)),
                        if (!box.isRacked) const _UnrackedTag(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${box.building.name} · Shelf ${box.shelfLetter}, Level ${box.shelfLevel}',
                      style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$days', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: days == 1 ? ' day stored' : ' days stored'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _FullnessBar(box.fullness),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small outlined "Unracked" tag.
class _UnrackedTag extends StatelessWidget {
  const _UnrackedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.field),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Unracked', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// A bar that is empty, half filled, or full, with the word next to it.
class _FullnessBar extends StatelessWidget {
  final Fullness fullness;

  const _FullnessBar(this.fullness);

  @override
  Widget build(BuildContext context) {
    final (fraction, fill, label) = switch (fullness) {
      Fullness.empty => (0.0, AppColors.barEmpty, 'Empty'),
      Fullness.half => (0.5, AppColors.half, 'Half'),
      Fullness.full => (1.0, AppColors.ink, 'Full'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.barEmpty,
            border: Border.all(color: AppColors.barBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: ColoredBox(color: fill),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink2))),
      ],
    );
  }
}
