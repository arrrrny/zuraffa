// SPEC 1124 (issue #1124) — the canonical `zuraffa.verdict.v1` envelope
// model (issue #1105) unit contract: stable schema identifier, omitted
// keys when a surface carries nothing, and single-line encoding.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';

void main() {
  group('ZuraffaVerdictEnvelope (issue #1105 canonical schema)', () {
    test('schema is exactly "zuraffa.verdict.v1"', () {
      expect(ZuraffaVerdictEnvelope.schema, 'zuraffa.verdict.v1');
    });

    test('the repository create pass envelope carries the SPEC 1124 keys', () {
      final envelope = ZuraffaVerdictEnvelope(
        command: 'zfa repository create',
        status: VerdictStatus.pass,
        exitClass: 0,
        subject: {'kind': 'repository', 'entity': 'Product'},
        manifest: {
          'path': '.zfa/receipts/repository-product.json',
          'sha256': 'a' * 64,
          'methods': ['get', 'update'],
        },
        timestamp: DateTime.parse('2026-09-07T00:00:00.000Z'),
      );

      final json = envelope.toJson();
      expect(json['schema'], 'zuraffa.verdict.v1');
      expect(json['command'], 'zfa repository create');
      expect(json['verdict'], 'pass');
      expect(json['exit_class'], 0);
      expect(json['subject'], {'kind': 'repository', 'entity': 'Product'});
      expect(json['findings'], isEmpty);
      expect(json['manifest'], isNotNull);
      expect(json['drifts'], isEmpty);
      expect(json['details'], isEmpty);
      expect(json['timestamp'], '2026-09-07T00:00:00.000Z');
    });

    test('a null subject/manifest omits the keys instead of lying', () {
      final envelope = ZuraffaVerdictEnvelope(
        command: 'zfa repository create',
        status: VerdictStatus.fail,
        exitClass: 1,
        timestamp: DateTime.parse('2026-09-07T00:00:00.000Z'),
      );
      final json = envelope.toJson();
      expect(json.containsKey('subject'), isFalse);
      expect(json.containsKey('manifest'), isFalse);
    });

    test('toJsonLine is single-line JSON that round-trips', () {
      final envelope = ZuraffaVerdictEnvelope(
        command: 'zfa repository create',
        status: VerdictStatus.fail,
        exitClass: 1,
        subject: {'kind': 'repository', 'entity': 'Product'},
        findings: [
          {
            'side': 'implementation',
            'kind': 'conformance_mismatch',
            'method': 'update',
            'fix': "--> fix: implement 'update'.",
          },
        ],
        details: {
          'expected_methods': ['get', 'update'],
          'actual_methods': ['get'],
        },
        timestamp: DateTime.parse('2026-09-07T00:00:00.000Z'),
      );

      final line = envelope.toJsonLine();
      expect(line, isNot(contains('\n')));

      final decoded = jsonDecode(line) as Map<String, dynamic>;
      expect(decoded['schema'], 'zuraffa.verdict.v1');
      final findings = decoded['findings'] as List;
      expect(
        (findings.single as Map<String, dynamic>)['kind'],
        'conformance_mismatch',
      );
      final details = decoded['details'] as Map;
      expect(details['expected_methods'], ['get', 'update']);
      expect(details['actual_methods'], ['get']);
    });

    test('verdict categories match the issue #1105 vocabulary', () {
      expect(VerdictStatus.values.map((s) => s.name).toSet(), {
        'pass',
        'fail',
        'skip',
        'error',
      });
    });
  });
}
