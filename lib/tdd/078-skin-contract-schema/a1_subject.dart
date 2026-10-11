// GENERATED TEST SUBJECT — `zfa tdd gen A1` (spec 044-test-tdd-generation).
//
// behavior_id: A1
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';

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

/// Scenario runner for behavior A1.
Future<void> subject_a1() async {
  final contract = parseSkinContractJson(validContractJson);
  expect(contract.schemaVersion, '1');
  expect(contract.routes.single.path, '/login');
  expect(contract.states.single.error, 'toaster');
  expect(contract.platformRows.single.ios, isTrue);
  expect(contract.stateRows.single.kind, 'observer');
}
