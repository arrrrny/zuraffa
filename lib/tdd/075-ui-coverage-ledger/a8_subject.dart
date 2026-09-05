library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_a8() {
  final ledger = fixtureLedger();
  final done = ledger.where((r) => r.state == 'DONE').toList();
  expect(done.length, 2);
  expect(
    done.map((r) => r.surface),
    containsAll(['Login button text', '/login']),
  );
  return null;
}
