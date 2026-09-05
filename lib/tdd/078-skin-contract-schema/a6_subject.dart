// GENERATED TEST SUBJECT — `zfa tdd gen A6` (spec 044-test-tdd-generation).
//
// behavior_id: A6
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';
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

/// Scenario runner for behavior A6.
Future<void> subject_a6() async {
  final specs = Directory('specs');
  var found = 0;
  for (final file
      in specs
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('spec.md'))) {
    final content = file.readAsStringSync();
    if (!RegExp('^## Skin Contract:', multiLine: true).hasMatch(content)) {
      continue;
    }
    found++;
    final contract = parseSkinContractDeclaration(content).contract;
    expect(schemaViolationsLite(contract.toJson()), isEmpty, reason: file.path);
  }
  expect(
    found,
    greaterThan(0),
    reason: 'no contract-bearing specs — the check must never pass vacuously',
  );
}

List<String> schemaViolationsLite(Map<String, dynamic> contract) {
  final violations = <String>[];
  final schema = skinContractSchema();
  final defs = schema[r'$defs'] as Map<String, dynamic>;
  for (final entry in SkinContract.sections.entries) {
    final rows = contract[entry.key];
    if (rows is! List) continue;
    final rowDef = defs[skinContractDefName(entry.key)] as Map<String, dynamic>;
    final props = rowDef['properties'] as Map<String, dynamic>;
    for (final (i, row) in rows.indexed) {
      if (row is! Map<String, dynamic>) continue;
      for (final key in row.keys) {
        if (!props.containsKey(key)) {
          violations.add('${entry.key}[$i]: unknown field "$key"');
        }
      }
      for (final required in (rowDef['required'] as List)) {
        if (!row.containsKey(required)) {
          violations.add('${entry.key}[$i]: missing "$required"');
        }
      }
    }
  }
  return violations;
}
