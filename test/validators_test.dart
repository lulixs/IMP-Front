import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/validators.dart';

void main() {
  group('validateTabletName', () {
    test('A missing, empty, or blank name is an error', () {
      for (final value in [null, '', '   ']) {
        expect(validateTabletName(value), 'Enter a tablet name', reason: '"$value"');
      }
    });

    test('Any characters are fine, and spaces around the name do not count', () {
      for (final value in ['A', ' A ', 'Front desk #2 (old)', '${'x' * 100}  ']) {
        expect(validateTabletName(value), isNull, reason: '"$value"');
      }
    });

    test('More than 100 characters is an error', () {
      expect(validateTabletName('x' * 101), 'Use 100 characters or fewer');
    });
  });
}
