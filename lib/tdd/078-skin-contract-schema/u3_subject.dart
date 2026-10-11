// GENERATED TEST SUBJECT — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:convert';

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

/// Scenario runner for behavior U3.
Future<void> subject_u3() async {
  final contract = parseSkinContractJson(validContractJson);
  final reparsed = parseSkinContractJson(
    const JsonEncoder.withIndent('  ').convert(contract.toJson()),
  );
  expect(reparsed, equals(contract));
}
