import 'package:flutter/material.dart';

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
  home: BoxPage(box: box, categories: categories, buildings: buildings),
  ));
}