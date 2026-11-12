import 'package:flutter_test/flutter_test.dart';
import 'package:imp_app/session.dart';

void main() {
  test('A new session keeps the employee name and starts with Master mode off', () {
    final session = Session(employeeName: 'Dan Finkle');

    expect(session.employeeName, 'Dan Finkle');
    expect(session.masterMode, isFalse);
  });

  test('Setting Master mode changes it and tells listeners, but only when it actually changes', () {
    final session = Session(employeeName: 'Dan Finkle');
    var told = 0;
    session.addListener(() => told++);

    session.masterMode = true;
    expect(session.masterMode, isTrue);
    expect(told, 1);

    session.masterMode = true;
    expect(told, 1, reason: 'already on, so nothing changed');

    session.masterMode = false;
    expect(session.masterMode, isFalse);
    expect(told, 2);
  });
}
