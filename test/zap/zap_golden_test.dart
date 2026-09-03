// Spec 071 (issue #809) — ZAP golden examples + published-contract drift
// gate.
//
// A1 + U12 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: the
// committed schemas/goldens under the spec dir must byte-equal the
// code-derived maps (the published contract cannot drift), and the golden
// examples must validate + round-trip (FR-006, SC-001).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_golden.dart';
import 'package:zuraffa/src/zap/zap_message.dart';
import 'package:zuraffa/src/zap/zap_schema.dart';
import 'package:zuraffa/src/zap/zap_validator.dart';

import '../helpers/project_root.dart';

void main() {
  test('U12: golden examples validate and round-trip', () async {
    final root = await findProjectRoot();
    expect(
      Directory('$root/specs/071-zuraffa-agent-protocol').existsSync(),
      isTrue,
      reason: 'the spec directory must exist',
    );

    for (final type in ['mission', 'evidence', 'checkpoint', 'receipt']) {
      final golden = ZapGoldens.example(type);

      final validation = ZapValidator.validate(golden);
      expect(
        validation.ok,
        isTrue,
        reason:
            '$type golden failed schema: '
            '${validation.issues.map((i) => '${i.path}: ${i.message}')}',
      );

      final typed = ZapMessage.fromJson(golden);
      expect(typed.toJson(), golden, reason: '$type golden must round-trip');
    }
  });

  test('A1: committed schemas and goldens match the code (no drift)', () async {
    final root = await findProjectRoot();
    final specDir = '$root/specs/071-zuraffa-agent-protocol';

    // Every code schema is committed, byte-equal.
    for (final entry in ZapSchema.all.entries) {
      final file = File('$specDir/schemas/${entry.key}.schema.json');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${entry.key}.schema.json must be committed '
            '(run `zfa zap schema --export specs/071-zuraffa-agent-protocol`)',
      );
      final committed = jsonDecode(file.readAsStringSync());
      expect(
        committed,
        entry.value,
        reason:
            '${entry.key}.schema.json drifted from the code — the '
            'published contract is stale; re-export it',
      );
    }

    // Every golden example is committed, byte-equal.
    for (final type in ['mission', 'evidence', 'checkpoint', 'receipt']) {
      final file = File('$specDir/golden/$type.golden.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: '$type.golden.json must be committed',
      );
      final committed = jsonDecode(file.readAsStringSync());
      expect(
        committed,
        ZapGoldens.example(type),
        reason: '$type.golden.json drifted from the code; re-export it',
      );
    }

    // No stray files in the published dirs.
    final schemaFiles = Directory(
      '$specDir/schemas',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
    expect(schemaFiles, {
      for (final t in ZapSchema.all.keys) '$t.schema.json',
    }, reason: 'no unpublished schema files may linger');
  });
}
