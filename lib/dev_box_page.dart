import 'package:flutter/material.dart';

import 'theme.dart';
import 'models/box.dart';
import 'models/building.dart';
import 'models/category.dart';
import 'screens/boxes/box_page.dart';
import 'screens/boxes/sample_box.dart';

void main() {
  final box = Box.fromJson(sampleBox);

  final categories = <Category>[];
  for (final c in sampleCategories) {
    categories.add(Category.fromJson(c));
  }

  final buildings = <Building>[];
  for (final b in sampleBuildings) {
    buildings.add(Building.fromJson(b));
  }

  runApp(MaterialApp(
    theme: buildTheme(),
    home: BoxPage(
      box: box,
      categories: categories,
      buildings: buildings,
      // Stand-ins until Connect plugs in the server (week 12). They print to the terminal.
      onSave: (changes) async => debugPrint('Save: ${changes.toJson()}'),
      onDelete: () async => debugPrint('Delete box ${box.id}'),
      onPrint: () => debugPrint('Print label for box ${box.id}'),
    ),
  ));
}