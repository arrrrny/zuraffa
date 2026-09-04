library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

Object? subject_u2() {
  final ledger = UiLedgerBuilder.derive(
    declared: [DeclaredSurface(surface: 'orphan', kind: UiSurfaceKind.text)],
    greenBehaviors: const {},
  );
  expect(ledger.length, 1);
  expect(ledger[0].state, 'NOT-DONE');
  expect(ledger[0].provers, isEmpty);
  return null;
}
