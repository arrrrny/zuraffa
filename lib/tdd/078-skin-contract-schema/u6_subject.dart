// GENERATED TEST SUBJECT — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_contract_emit.dart';
import 'dart:io';

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

/// Scenario runner for behavior U6.
Future<void> subject_u6() async {
  // The repo-wide walk is the standing suite (schema_test.dart); the
  // subject proves it on the live tree.
  final specs = Directory('specs')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('spec.md'))
      .where(
        (f) => RegExp(
          '^## Skin Contract:',
          multiLine: true,
        ).hasMatch(f.readAsStringSync()),
      )
      .toList();
  expect(specs, isNotEmpty);
  for (final file in specs) {
    final contract = parseSkinContractJson(
      skinContractJsonFromSpec(file.readAsStringSync())!,
    );
    expect(contract.schemaVersion, '1', reason: file.path);
  }
}
