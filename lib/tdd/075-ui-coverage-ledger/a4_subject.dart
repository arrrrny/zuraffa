library;

import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

Object? subject_a4() {
  final ledger = UiLedgerBuilder.derive(
    declared: const [],
    greenBehaviors: const {},
  );
  expect(ledger, isEmpty, reason: 'no declared surfaces means no rows');
  return null;
}
