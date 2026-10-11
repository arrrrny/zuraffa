// Repo-wide skin-contract schema conformance (issue #1164, US3/A6-A7, U6).
//
// Walks every spec under `specs/`, discovers `## Skin Contract:` sections,
// parses the contract JSON, and validates it against the generated schema.
// A vacuous pass is dishonest: zero contract-bearing specs fails the suite.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_parser.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';

/// Walks `specs/` and returns every contract-bearing spec as
/// (path, section JSON body).
List<(String, String)> contractBearingSpecs(String specsRoot) {
  final results = <(String, String)>[];
  final root = Directory(specsRoot);
  if (!root.existsSync()) return results;
  for (final file
      in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('spec.md'))) {
    final content = file.readAsStringSync();
    final marker =
        RegExp(
          '^## Skin Contract:',
          multiLine: true,
        ).firstMatch(content)?.start ??
        -1;
    if (marker < 0) continue;
    if (marker < 0) continue;
    final bodyRegion = content
        .substring(marker)
        .substring(content.substring(marker).indexOf('\n') + 1);
    final open = RegExp(
      r'^```json\s*$',
      multiLine: true,
    ).firstMatch(bodyRegion);
    if (open == null) {
      results.add((file.path, ''));
      continue;
    }
    final close = bodyRegion.indexOf('```', open.end);
    results.add((
      file.path,
      close < 0 ? '' : bodyRegion.substring(open.end, close).trim(),
    ));
  }
  return results;
}

/// Validates a parsed contract against the generated schema — the subset
/// of JSON Schema semantics the generator emits (types, required,
/// additionalProperties, enum, pattern, const).
List<String> schemaViolations(
  Map<String, dynamic> contract,
  Map<String, dynamic> schema,
) {
  final violations = <String>[];
  void checkObject(
    Map<String, dynamic> obj,
    Map<String, dynamic> def,
    String where,
  ) {
    for (final required in (def['required'] as List<dynamic>)) {
      if (!obj.containsKey(required)) {
        violations.add('$where: missing "$required"');
      }
    }
    final properties = def['properties'] as Map<String, dynamic>;
    for (final key in obj.keys) {
      if (!properties.containsKey(key)) {
        violations.add('$where: unknown field "$key"');
      }
    }
    for (final entry in properties.entries) {
      final value = obj[entry.key];
      if (value == null) continue;
      final propSchema = entry.value as Map<String, dynamic>;
      if (propSchema.containsKey('const') && propSchema['const'] != value) {
        violations.add(
          '$where: "${entry.key}" must be "${propSchema['const']}"',
        );
      }
      if (propSchema['type'] == 'string' && value is! String) {
        violations.add('$where: "${entry.key}" must be a string');
      }
      if (propSchema['type'] == 'boolean' && value is! bool) {
        violations.add('$where: "${entry.key}" must be a boolean');
      }
      if (propSchema.containsKey('enum') &&
          !(propSchema['enum'] as List<dynamic>).contains(value)) {
        violations.add(
          '$where: "${entry.key}" value "$value" not in schema enum',
        );
      }
      if (propSchema.containsKey('pattern') &&
          !RegExp(propSchema['pattern'] as String).hasMatch(value as String)) {
        violations.add('$where: "${entry.key}" violates the schema pattern');
      }
    }
  }

  checkObject(contract, schema, 'contract');
  for (final entry in SkinContract.sections.entries) {
    final rows = contract[entry.key];
    if (rows is! List) continue;
    final defs = schema[r'$defs'] as Map<String, dynamic>;
    final rowDef = defs[skinContractDefName(entry.key)] as Map<String, dynamic>;
    for (final (index, row) in rows.indexed) {
      if (row is Map<String, dynamic>) {
        checkObject(row, rowDef, '${entry.key}[$index]');
      }
    }
  }
  return violations;
}

void main() {
  final specsRoot = p.join(Directory.current.path, 'specs');

  test('A6/U6: every contract-bearing spec parses and validates', () {
    final specs = contractBearingSpecs(specsRoot);
    expect(
      specs,
      isNotEmpty,
      reason:
          'no contract-bearing specs found — the schema test must '
          'never pass vacuously; declare `## Skin Contract:` on a real '
          'spec first',
    );
    for (final (path, body) in specs) {
      expect(
        body,
        isNotEmpty,
        reason: '$path: Skin Contract section has no JSON body',
      );
      final contract = parseSkinContractJson(body);
      final violations = schemaViolations(
        contract.toJson(),
        skinContractSchema(),
      );
      expect(violations, isEmpty, reason: '$path: ${violations.join('; ')}');
    }
  });

  test('A7/U6: a violating contract fails naming the spec and key', () {
    final broken = '''
{
  "schemaVersion": "2",
  "routes": [],
  "states": [],
  "platformRows": [],
  "stateRows": []
}
''';
    expect(
      () => parseSkinContractJson(broken),
      throwsA(
        isA<SkinContractParseException>().having(
          (e) => e.message,
          'message',
          allOf(contains('schemaVersion'), contains('"2"')),
        ),
      ),
    );
  });

  test('the generated schema is itself valid JSON Schema shape', () {
    final schema = skinContractSchema();
    expect(schema[r'$schema'], contains('json-schema.org'));
    expect(schema['type'], 'object');
    expect(schema['additionalProperties'], isFalse);
    expect(schema[r'$defs'], isA<Map<String, dynamic>>());
    final encoded = jsonEncode(schema);
    expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
  });
}
