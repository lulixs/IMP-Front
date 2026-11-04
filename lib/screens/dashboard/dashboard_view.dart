import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../../theme.dart';
import 'category_card.dart';

/// The dashboard's content (wireframe 03a): title, headline, the fullness key, and
/// one card per category. It only draws the [DashboardData] it is given and never
/// loads data itself, so it works the same with sample data or the API's.
class DashboardView extends StatelessWidget {
  final DashboardData data;

  /// True while [data] is the sample, not a response from the server.
  final bool isSample;

  const DashboardView({super.key, required this.data, this.isSample = false});

  /// One CategoryCard per category in [data], in the order given.
  List<Widget> _cards() {
    final cards = <Widget>[];

    for (final cat in data.categories) {
      cards.add(CategoryCard(category: cat, isSample: isSample));
    }

    return cards;
  }

  String _headline() {
    var boxes = 0;
    for (final category in data.categories) {
      boxes += category.total;
    }
    final categories = data.categories.length;
    final headline = '$boxes racked ${boxes == 1 ? 'box' : 'boxes'} in '
        '$categories ${categories == 1 ? 'category' : 'categories'}.';
    return isSample ? '$headline Sample data, not from the server.' : headline;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_headline(), style: const TextStyle(fontSize: 13.5, color: AppColors.ink2)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _KeyItem(AppColors.ink, 'Full'),
                    _KeyItem(AppColors.half, 'Half'),
                    _KeyItem(AppColors.barEmpty, 'Empty'),
                    Text(
                      'Unracked and deleted boxes are not counted',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.ink2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No categories yet.', style: TextStyle(fontSize: 14, color: AppColors.ink3)),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // 3 cards per row on a tablet, fewer on narrower screens.
                      const gap = 12.0;
                      final columns = constraints.maxWidth >= 700 ? 3 : (constraints.maxWidth >= 440 ? 2 : 1);
                      // Rounded down so rounding can't push the last card onto the next row.
                      final cardWidth = ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
                      // Cards are as tall as their text, so a long line or a larger system
                      // text size makes the card taller instead of cutting it off.
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [for (final card in _cards()) SizedBox(width: cardWidth, child: card)],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One entry in the Full / Half / Empty key.
class _KeyItem extends StatelessWidget {
  final Color color;
  final String label;

  const _KeyItem(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.ink3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
