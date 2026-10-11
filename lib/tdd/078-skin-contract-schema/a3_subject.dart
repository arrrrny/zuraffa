// GENERATED TEST SUBJECT — `zfa tdd gen A3` (spec 044-test-tdd-generation).
//
// behavior_id: A3
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
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

/// Scenario runner for behavior A3.
Future<void> subject_a3() async {
  final out = Directory.systemTemp.createTempSync('a3-schema-');
  addTearDown(() => out.deleteSync(recursive: true));
  final written = await emitSkinContractSchema(
    specMarkdown:
        '# S\n\n## Skin Contract: x\n\n```json\n$validContractJson\n```\n',
    outDir: out,
  );
  expect(written, isNotNull);
  expect(File(written!).readAsStringSync(), contains('"const": "1"'));
}
