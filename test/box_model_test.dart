import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:imp_app/models/box.dart';
import 'package:imp_app/models/building.dart';
import 'package:imp_app/models/category.dart';

void main() {
  const boxJson = '''
    {
    "id": 6789,
    "category": { "id": 1, "name": "Coats", "symbol": "🧥" },
    "building": { "id": 2, "name": "Processing Center" },
    "shelfLetter": "A",
    "shelfLevel": 2,
    "fullness": "FULL",
    "notes": "Mostly adult sizes. Check zippers before putting out.",
    "isRacked": true,
    "rackedSince": "2026-01-14",
    "daysStored": 299,
    "storedTooLong": true,
    "createdAt": "2025-12-03T14:32:00Z",
    "createdBy": { "id": 1, "name": "Daniel Finkle" },
    "lastUpdatedAt": "2026-10-07T18:05:00Z",
    "lastUpdatedBy": { "id": 4, "name": "Grace Kim" },
    "deletedAt": null,
    "deletedBy": null
    }
  ''';

  test('Reads a category with a symbol', () {
    final json = jsonDecode('{"id": 1, "name": "Coats", "symbol": "🧥"}');
    final category = Category.fromJson(json);

    // expect(expected, actual)
    expect(category.id, 1);
    expect(category.name, "Coats");
    expect(category.symbol, "🧥");
  });

  test('Reads a category without a symbol', () {
    final json = jsonDecode('{"id": 1, "name": "Coats", "symbol": null}');
    final category = Category.fromJson(json);

    expect(category.id, 1);
    expect(category.name, "Coats");
    expect(category.symbol, null);
  });

  test('Reads the attributes of a box, excluding possible nulls', () {
    final json = jsonDecode(boxJson);
    final box = Box.fromJson(json);

    expect(box.id, 6789);
    expect(box.category.name, "Coats");
    expect(box.building.name, "Processing Center");
    expect(box.shelfLetter, "A");
    expect(box.shelfLevel, 2);
    expect(box.isRacked, true);
    expect(box.createdBy.name, "Daniel Finkle");
    expect(box.fullness, Fullness.full);
    expect(box.rackedSince, DateTime(2026, 01, 14));
    expect(box.lastUpdatedBy!.name, "Grace Kim");
  });

  test('Reads a building', () {
    final json = jsonDecode('{"id": 1, "name": "Processing Center"}');
    final building = Building.fromJson(json);

    expect(building.id, 1);
    expect(building.name, "Processing Center");
  });

  test('Reads a box that has never been edited or if it has been deleted(null cases)', () {
    final json = jsonDecode(boxJson);

    json["lastUpdatedBy"] = null;
    json["lastUpdatedAt"] = null;

    final box = Box.fromJson(json);

    expect(box.lastUpdatedAt, null);
    expect(box.lastUpdatedBy, null);
    expect(box.deletedAt, null);
    expect(box.deletedBy, null);
  });

  test('An unknown fullness throws', () {
  final json = jsonDecode(boxJson);
  json["fullness"] = "RANDOM";

  expect(() => Box.fromJson(json), throwsFormatException);
});
}
