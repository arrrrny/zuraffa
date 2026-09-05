// GENERATED TEST SUBJECT — `zfa tdd gen A7` (spec 044-test-tdd-generation).
//
// behavior_id: A7
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

/// Scenario runner for behavior A7.
Future<void> subject_a7() async {
  final broken = '''
{
  "schemaVersion": "7",
  "routes": [],
  "states": [],
  "platformRows": [],
  "stateRows": []
}
''';
  try {
    parseSkinContractJson(broken);
    fail('expected the broken contract to fail');
  } on SkinContractParseException catch (error) {
    expect(error.message, allOf(contains('schemaVersion'), contains('"7"')));
  }
}
