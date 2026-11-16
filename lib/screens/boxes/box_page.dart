import 'package:flutter/material.dart';
import '../../theme.dart';

import '../../models/box.dart';
import '../../models/building.dart';
import '../../models/category.dart';

// Box Screen
class BoxPage extends StatefulWidget {
  final Box box;
  final List<Category> categories;
  final List<Building> buildings;

  const BoxPage({
    super.key,
    required this.box,
    required this.categories,
    required this.buildings,
  });

  @override
  State<BoxPage> createState() {
    return _BoxPageState();
  }
}

class _BoxPageState extends State<BoxPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                // back button
                IconButton.outlined(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 16),

                // Title and Subtitle stack
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // box title and number
                    Text(
                      'Box #${widget.box.id}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [

                        // box name
                        Text('${widget.box.category.name} · '),

                        // box for labeling: racked or unracked
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.box.isRacked ? AppColors.ink : AppColors.panel,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.box.isRacked ? 'Racked' : 'Unracked',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: widget.box.isRacked ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // print button
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.print),
                  label: const Text('Print label'),
                ),
              ],
            ),
          ),
          // The cards go here
        ],
      ),
    );
  }
}