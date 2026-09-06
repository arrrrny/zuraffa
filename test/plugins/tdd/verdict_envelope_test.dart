/// Unit tests for VerdictEnvelope (issue #964, VISION §3 §4 §5).
///
/// EPIC 1150 migration: the wire shape is the canonical
/// `zuraffa.verdict.v1` envelope. The legacy keys the verbs populate
/// (verdict/exit_label/feature/details) are preserved INSIDE `data`.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/verdict_envelope.dart';

void main() {
  group('VerdictEnvelope', () {
    test('U1: toJsonLine emits the canonical schema with required keys', () {
      final envelope = VerdictEnvelope(
        command: 'run',
        outcome: VerdictOutcome.pass,
        details: <String, Object?>{'green': 22},
        feature: '073-slice-isolation',
        timestamp: DateTime.utc(2026, 9, 4, 12, 0, 0),
      );
      final line = envelope.toJsonLine();
      final decoded = jsonDecode(line) as Map<String, Object?>;
      // Canonical envelope keys.
      expect(decoded['schema'], 'zuraffa.verdict.v1');
      expect(decoded['command'], 'zfa tdd run');
      expect(decoded['result'], 'ok');
      expect(decoded['exit_class'], 0);
      expect(decoded['message'], isA<String>());
      expect(decoded['ts'], '2026-09-04T12:00:00.000Z');
      // Legacy key surface preserved inside `data`.
      final data = decoded['data'] as Map<String, Object?>;
      expect(data['verdict'], 'pass');
      expect(data['feature'], '073-slice-isolation');
      expect(data['green'], 22);
    });

    test('U2: emit() output is valid JSON parseable by jsonDecode', () {
      final envelope = VerdictEnvelope(
        command: 'gen',
        outcome: VerdictOutcome.pass,
        details: <String, Object?>{'created': 3, 'reused': 1},
      );
      final line = envelope.toJsonLine();
      expect(() => jsonDecode(line), returnsNormally);
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['command'], 'zfa tdd gen');
      expect(decoded['result'], 'ok');
      final data = decoded['data'] as Map<String, Object?>;
      expect(data['verdict'], 'pass');
      expect(data['created'], 3);
      expect(data['reused'], 1);
    });

    test('U3: schema name is exactly "zuraffa.verdict.v1" (no drift)', () {
      expect(VerdictEnvelope.schema, 'zuraffa.verdict.v1');
    });

    test('U3b: every outcome maps onto the canonical result vocabulary', () {
      const expectedResults = {
        VerdictOutcome.pass: 'ok',
        VerdictOutcome.fail: 'error',
        VerdictOutcome.stopped: 'skipped',
        VerdictOutcome.error: 'error',
        VerdictOutcome.refused: 'refused',
      };
      for (final outcome in VerdictOutcome.values) {
        final envelope = VerdictEnvelope(command: 'run', outcome: outcome);
        final decoded =
            jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
        expect(decoded['result'], expectedResults[outcome]);
        expect(
          (decoded['data'] as Map<String, Object?>)['verdict'],
          outcome.name,
          reason: 'the raw legacy verdict name is kept in data',
        );
      }
    });

    test('feature is omitted from data when null/empty', () {
      final envelope = VerdictEnvelope(
        command: 'reset',
        outcome: VerdictOutcome.pass,
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(
        (decoded['data'] as Map<String, Object?>).containsKey('feature'),
        isFalse,
      );
    });

    test('details merge into data; exit_label defaults by outcome', () {
      final envelope = VerdictEnvelope(
        command: 'run',
        outcome: VerdictOutcome.fail,
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(
        decoded['exit_class'],
        1,
        reason: 'fail = honest negative, exit 1',
      );
      final data = decoded['data'] as Map<String, Object?>;
      expect(data['exit_label'], 'fail');
      expect(data['verdict'], 'fail');
    });

    test('exit_code wins over the outcome default (wrapper contract)', () {
      final envelope = VerdictEnvelope(
        command: 'run',
        outcome: VerdictOutcome.pass,
        exitCode: 0,
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(decoded['exit_class'], 0);
    });

    test('commandPrefix: non-TDD carriers name their true producer', () {
      final envelope = VerdictEnvelope(
        command: 'di verify',
        outcome: VerdictOutcome.pass,
        commandPrefix: 'zfa',
      );
      final decoded = jsonDecode(envelope.toJsonLine()) as Map<String, Object?>;
      expect(decoded['command'], 'zfa di verify');
    });
  });
}
