// GENERATED TEST SUBJECT — `zfa tdd gen A5` (spec 044-test-tdd-generation).
//
// behavior_id: A5
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

/// Scenario runner for behavior A5.
Future<void> subject_a5() async {
  final out = Directory.systemTemp.createTempSync('a5-schema-');
  addTearDown(() => out.deleteSync(recursive: true));
  final written = await emitSkinContractSchema(
    specMarkdown: '# S\n\nno contract here\n',
    outDir: out,
  );
  expect(written, isNull);
  expect(out.listSync(), isEmpty);
}
