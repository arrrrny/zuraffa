/// Unit tests for VerdictEnvelope (issue #964, VISION §3 §4 §5).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/verdict_envelope.dart';

void main() {
  group('VerdictEnvelope', () {
    test(
      'U1: toJsonLine emits stable verdict.v1 schema with required keys',
      () {
        final envelope = VerdictEnvelope(
          command: 'run',
          outcome: VerdictOutcome.pass,
          details: <String, Object?>{
            'feature': '073-slice-isolation',
            'green': 22,
          },
          feature: '073-slice-isolation',
          timestamp: DateTime.utc(2026, 9, 4, 12, 0, 0),
        );
        final line = envelope.toJsonLine();
        final decoded = jsonDecode(line) as Map<String, Object?>;
        expect(decoded['schema'], 'verdict.v1');
        expect(decoded['command'], 'run');
        expect(decoded['verdict'], 'pass');
        expect(decoded['feature'], '073-slice-isolation');
        expect(decoded['details'], isA<Map<String, Object?>>());
        expect((decoded['details'] as Map<String, Object?>)['green'], 22);
        expect(decoded['timestamp'], '2026-09-04T12:00:00.000Z');
      },
    );

    test('U2: emit() returns valid JSON parseable by jsonDecode', () {
      final envelope = VerdictEnvelope(
        command: 'gen',
        outcome: VerdictOutcome.pass,
        details: <String, Object?>{'created': 3, 'reused': 1},
      );
      final line = envelope.toJsonLine();
      expect(() => jsonDecode(line), returnsNormally);
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['command'], 'gen');
      expect(decoded['verdict'], 'pass');
      final details = decoded['details'] as Map<String, Object?>;
      expect(details['created'], 3);
      expect(details['reused'], 1);
    });

    test('U3: schema name is exactly "verdict.v1" (no drift)', () {
      expect(VerdictEnvelope.schema, 'verdict.v1');
    });

    test('U3b: every verdict enum is preserved in JSON', () {
      for (final outcome in VerdictOutcome.values) {
        final envelope = VerdictEnvelope(command: 'run', outcome: outcome);
        final decoded =
            jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
        expect(decoded['verdict'], outcome.name);
      }
    });

    test('feature is omitted from JSON when null/empty', () {
      final envelope = VerdictEnvelope(
        command: 'reset',
        outcome: VerdictOutcome.pass,
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(decoded.containsKey('feature'), isFalse);
    });

    test('details defaults to empty map', () {
      final envelope = VerdictEnvelope(
        command: 'run',
        outcome: VerdictOutcome.pass,
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(decoded['details'], <String, Object?>{});
    });
  });
}
