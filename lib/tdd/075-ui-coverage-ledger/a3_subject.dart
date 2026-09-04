library;

import 'package:test/test.dart';
import 'sandbox_fixture.dart';

Object? subject_a3() {
  final ledger = fixtureLedger();
  final submit = ledger.firstWhere((r) => r.surface == 'submit form');
  expect(submit.state, 'NOT-DONE');
  expect(submit.provers, isEmpty);
  return null;
}
