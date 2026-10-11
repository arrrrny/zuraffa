// GENERATED TEST SUBJECT — `zfa tdd gen A4` (spec 044-test-tdd-generation).
//
// behavior_id: A4
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';

const validContractJson = '''
{
  "schemaVersion": "1",
  "routes": [
    { "path": "/login", "view": "LoginPage" }
  ],
  "states": [
    { "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }
  ],
  "platformRows": [
    { "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }
  ],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" }
  ]
}
''';

/// Scenario runner for behavior A4.
Future<void> subject_a4() async {
  final schema = skinContractSchema();
  final properties = schema['properties'] as Map<String, dynamic>;
  expect(properties.keys, containsAll(SkinContract.sections.keys));
  final defs = schema[r'$defs'] as Map<String, dynamic>;
  for (final entry in SkinContract.sections.entries) {
    final rowDef = defs[skinContractDefName(entry.key)] as Map<String, dynamic>;
    final props = rowDef['properties'] as Map<String, dynamic>;
    expect(
      props.keys,
      equals(entry.value.map((f) => f.name)),
      reason: 'section ${entry.key} must not drift from the model',
    );
  }
}
