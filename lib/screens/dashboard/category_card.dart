import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../../theme.dart';

/// One category on the dashboard (wireframe 03a): name, racked box count, the
/// fullness bar and counts, and how many boxes are stored too long.
class CategoryCard extends StatelessWidget {
  final DashboardCategory category;

  /// Shows a SAMPLE tag, for data that did not come from the server.
  final bool isSample;

  const CategoryCard({super.key, required this.category, this.isSample = false});

  @override
  Widget build(BuildContext context) {
    final c = category;
    final symbol = c.symbol;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: Text(
                    symbol == null ? c.name : '$symbol ${c.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                ),
              ),
              if (isSample) const _Tag('SAMPLE', dark: false),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${c.total}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                TextSpan(text: c.total == 1 ? ' racked box' : ' racked boxes'),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.ink2),
          ),
          const SizedBox(height: 9),
          _FullnessBar(full: c.fullCount, half: c.halfCount, empty: c.emptyCount),
          const SizedBox(height: 7),
          Text(
            '${c.fullCount} full   ${c.halfCount} half   ${c.emptyCount} empty',
            style: const TextStyle(fontSize: 12, color: AppColors.ink2),
          ),
          const SizedBox(height: 14),
          if (c.storedTooLongCount > 0)
            _Tag('${c.storedTooLongCount} stored too long', dark: true)
          else
            const Text('No alerts', style: TextStyle(fontSize: 12, color: AppColors.ink3)),
        ],
      ),
    );
  }
}

/// Bar split into full, half, and empty parts, each as wide as its share of the boxes.
class _FullnessBar extends StatelessWidget {
  final int full;
  final int half;
  final int empty;

  const _FullnessBar({required this.full, required this.half, required this.empty});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.barEmpty,
        border: Border.all(color: AppColors.barBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      // With no boxes the bar stays empty. Expanded needs a flex above 0, so parts
      // with no boxes are left out rather than given a width of 0.
      child: Row(
        children: [
          if (full > 0) Expanded(flex: full, child: Container(color: AppColors.ink)),
          if (half > 0) Expanded(flex: half, child: Container(color: AppColors.half)),
          if (empty > 0) Expanded(flex: empty, child: Container(color: AppColors.barEmpty)),
        ],
      ),
    );
  }
}

/// Small rounded label: dark for alerts, outlined for SAMPLE.
class _Tag extends StatelessWidget {
  final String text;
  final bool dark;

  const _Tag(this.text, {required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : AppColors.card,
        border: Border.all(color: dark ? AppColors.ink : AppColors.ink2, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: dark ? Colors.white : AppColors.ink2),
      ),
    );
  }
}
