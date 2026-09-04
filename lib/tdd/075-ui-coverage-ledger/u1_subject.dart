library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

Object? subject_u1() {
  final ledger = fixtureLedger();
  expect(ledger.length, 3);
  for (final row in ledger) {
    expect(row.surface, isNotEmpty);
    expect(row.kind, isNotNull);
    expect(row.state, isNotEmpty);
  }
  return null;
}
