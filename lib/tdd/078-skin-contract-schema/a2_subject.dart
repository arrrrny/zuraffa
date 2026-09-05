// GENERATED TEST SUBJECT — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
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

/// Scenario runner for behavior A2.
Future<void> subject_a2() async {
  final broken = validContractJson.replaceFirst('"toaster"', '"banner"');
  expect(
    () => parseSkinContractJson(broken),
    throwsA(
      isA<SkinContractParseException>().having(
        (e) => e.message,
        'message',
        allOf(contains('"error"'), contains('"banner"')),
      ),
    ),
  );
}
