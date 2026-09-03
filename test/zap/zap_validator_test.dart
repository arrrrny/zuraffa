// Spec 071 (issue #809) — ZAP structural validation layer.
//
// U4–U7 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: every
// message passes the draft-07 subset validator BEFORE typed parsing, with
// precise JSON-path errors — hallucinated tool calls are structurally
// impossible (FR-007).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_golden.dart';
import 'package:zuraffa/src/zap/zap_schema.dart';
import 'package:zuraffa/src/zap/zap_validator.dart';

/// Deep-copies a JSON-ish map (mutating the copy never leaks into the
/// golden).
Map<String, Object?> clone(Map<String, Object?> src) =>
    (jsonDecode(jsonEncode(src)) as Map).cast<String, Object?>();

void main() {
  final missionGolden = ZapGoldens.example('mission');

  group('ZapValidator — positive (U4)', () {
    test('U4: the golden mission validates', () {
      final result = ZapValidator.validate(missionGolden);
      expect(result.ok, isTrue, reason: result.issues.join('\n'));
      expect(result.issues, isEmpty);
    });

    test('U4: every golden example validates against its schema', () {
      for (final type in ['mission', 'evidence', 'checkpoint', 'receipt']) {
        final result = ZapValidator.validate(ZapGoldens.example(type));
        expect(
          result.ok,
          isTrue,
          reason: '$type golden: ${result.issues.join('\n')}',
        );
      }
    });
  });

  group('ZapValidator — missing required fields (U5)', () {
    test('U5: a missing top-level required field is named by path', () {
      final broken = clone(missionGolden)..remove('missionId');
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any((i) => i.path == 'missionId'),
        isTrue,
        reason:
            'the issue must name `missionId`, got: '
            '${result.issues.map((i) => '${i.path}: ${i.message}')}',
      );
    });

    test('U5: a missing nested field is named with its full path', () {
      final broken = clone(missionGolden);
      (broken['budget'] as Map).remove('maxSteps');
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any((i) => i.path == 'budget.maxSteps'),
        isTrue,
        reason: result.issues.map((i) => '${i.path}: ${i.message}').join('\n'),
      );
    });

    test('U5: a missing array-item field is named with its index', () {
      final broken = clone(missionGolden);
      ((broken['steps'] as List)[0] as Map).remove('phase');
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any((i) => i.path == 'steps[0].phase'),
        isTrue,
        reason: result.issues.map((i) => '${i.path}: ${i.message}').join('\n'),
      );
    });
  });

  group('ZapValidator — types, enums, patterns, bounds (U6)', () {
    test('U6: a wrong property type is rejected with the path', () {
      final broken = clone(missionGolden);
      broken['goal'] = 42;
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any(
          (i) => i.path == 'goal' && i.message.contains('string'),
        ),
        isTrue,
        reason: result.issues.map((i) => '${i.path}: ${i.message}').join('\n'),
      );
    });

    test('U6: a bad enum value is rejected with the allowed set', () {
      final broken = clone(missionGolden);
      ((broken['steps'] as List)[0] as Map)['phase'] = 'vibes';
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any(
          (i) => i.path == 'steps[0].phase' && i.message.contains('red'),
        ),
        isTrue,
        reason: 'the message must name the allowed enum values',
      );
    });

    test('U6: a bad timestamp pattern is rejected', () {
      final broken = clone(missionGolden);
      broken['ts'] = '2026-09-03 10:00:00'; // missing T and Z
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(result.issues.any((i) => i.path == 'ts'), isTrue);
    });

    test('U6: a non-hex digest is rejected (evidence)', () {
      final broken = clone(ZapGoldens.example('evidence'));
      broken['digest'] = 'NOT-A-SHA256';
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(result.issues.any((i) => i.path == 'digest'), isTrue);
    });

    test('U6: minimum bounds are enforced (maxSteps)', () {
      final broken = clone(missionGolden);
      (broken['budget'] as Map)['maxSteps'] = 0;
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(result.issues.any((i) => i.path == 'budget.maxSteps'), isTrue);
    });

    test('U6: minItems is enforced (empty steps)', () {
      final broken = clone(missionGolden);
      broken['steps'] = <Object?>[];
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(result.issues.any((i) => i.path == 'steps'), isTrue);
    });
  });

  group('ZapValidator — closed envelopes and roots (U7)', () {
    test('U7: unknown top-level fields are rejected', () {
      final broken = clone(missionGolden);
      broken['priority'] = 'URGENT'; // hallucinated field
      final result = ZapValidator.validate(broken);
      expect(result.ok, isFalse);
      expect(
        result.issues.any((i) => i.path == 'priority'),
        isTrue,
        reason: 'a hallucinated envelope field must be named',
      );
    });

    test('U7: a non-object document is rejected', () {
      final result = ZapValidator.validateRaw('not-a-map');
      expect(result.ok, isFalse);
      expect(
        result.issues.any((i) => i.message.contains('object')),
        isTrue,
        reason: result.issues.map((i) => i.message).join('\n'),
      );
    });

    test('U7: a JSON array root is rejected', () {
      final result = ZapValidator.validateRaw([1, 2, 3]);
      expect(result.ok, isFalse);
    });

    test('U7: an unknown message type is rejected at the envelope', () {
      final result = ZapValidator.validate({
        'zap': '0.1',
        'type': 'telepathy',
        'id': 'x',
        'ts': '2026-09-03T10:00:00Z',
      });
      expect(result.ok, isFalse);
      expect(result.issues.any((i) => i.path == 'type'), isTrue);
    });

    test('U7: validate() with an explicit schema validates against it', () {
      // Direct schema use — the third-party path (validating against a
      // schema taken from the published files, not the dispatch).
      final result = ZapValidator.validate(
        clone(missionGolden),
        schema: ZapSchema.forType('mission'),
      );
      expect(result.ok, isTrue);
    });
  });
}
