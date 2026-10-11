// GENERATED TEST SUBJECT — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// Implemented for feature 079-skin-contract-binding (issue #1165): the
// subject drives the REAL runtime binding — the TDD green step.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'dart:io';

Future<void> subject_u6() async {
  final source = File(
    'lib/src/skin/skin_contract_binding.dart',
  ).readAsStringSync();
  expect(
    source.contains('package:flutter'),
    isFalse,
    reason: 'the binding is engine lane — zero UI-framework imports',
  );
  expect(source.contains('package:zuraffa_ui'), isFalse);
}
