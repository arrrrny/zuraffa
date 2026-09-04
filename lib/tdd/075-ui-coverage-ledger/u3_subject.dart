library;
import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

Object? subject_u3() {
  final ledger = UiLedgerBuilder.derive(
    declared: [DeclaredSurface(surface: 'x', kind: UiSurfaceKind.text, declaredProvers: ['A1', 'A2'])],
    greenBehaviors: {'A1'},
  );
  expect(ledger[0].state, 'DONE');
  expect(ledger[0].provers, ['A1']);
  return null;
}
