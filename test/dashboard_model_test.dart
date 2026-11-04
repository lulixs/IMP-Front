import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/models/dashboard.dart';

void main() {
  // The example from docs/api/dashboard.md in the backend repo.
  const contractExample = '''
{
  "alertThresholdDays": 180,
  "categories": [
    { "id": 1, "name": "Coats", "symbol": "🧥", "full": 3, "half": 2, "empty": 1, "storedTooLong": 3 },
    { "id": 2, "name": "Easter Baskets", "symbol": null, "full": 0, "half": 0, "empty": 0, "storedTooLong": 0 }
  ]
}
''';

  DashboardData parse(String body) => DashboardData.fromJson(jsonDecode(body) as Map<String, dynamic>);

  test('Parses the threshold and every category', () {
    final data = parse(contractExample);

    expect(data.alertThresholdDays, 180);
    expect(data.categories, hasLength(2));
  });

  test('Reads every category field', () {
    final coats = parse(contractExample).categories[0];

    expect(coats.id, 1);
    expect(coats.name, 'Coats');
    expect(coats.symbol, '🧥');
    expect(coats.fullCount, 3);
    expect(coats.halfCount, 2);
    expect(coats.emptyCount, 1);
    expect(coats.storedTooLongCount, 3);
  });

  test('Total is full + half + empty', () {
    final data = parse(contractExample);

    expect(data.categories[0].total, 6);
    expect(data.categories[1].total, 0);
  });

  test('A category with no symbol', () {
    final easter = parse(contractExample).categories[1];

    expect(easter.symbol, isNull);
  });

  test('An empty category list', () {
    final data = parse('{"alertThresholdDays": 90, "categories": []}');

    expect(data.alertThresholdDays, 90);
    expect(data.categories, isEmpty);
  });

  test('A missing key fails instead of quietly becoming null', () {
    const missingEmpty = '''
{ "alertThresholdDays": 180,
  "categories": [ { "id": 1, "name": "Coats", "symbol": null, "full": 3, "half": 2, "storedTooLong": 0 } ] }
''';

    expect(() => parse(missingEmpty), throwsA(isA<TypeError>()));
  });
}
