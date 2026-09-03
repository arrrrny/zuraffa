// Spec 071 (issue #809) — ZAP schema layer pins.
//
// U1–U3 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: every
// message type has a draft-07 JSON Schema with the closed envelope, and
// the mission schema pins the v0 contract (FR-002, FR-006).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_schema.dart';

void main() {
  group('ZapSchema — draft-07 per message type (U1)', () {
    for (final type in [
      'mission',
      'evidence',
      'checkpoint',
      'receipt',
      'error',
    ]) {
      test('U1: $type has a draft-07 schema with the envelope', () {
        final schema = ZapSchema.forType(type);

        expect(
          schema['\$schema'],
          'http://json-schema.org/draft-07/schema#',
          reason: '$type must declare draft-07',
        );
        expect(
          schema['type'],
          'object',
          reason: '$type root must be an object',
        );
        final required = schema['required'] as List;
        expect(required, isNotEmpty, reason: '$type must require fields');

        // The envelope: zap/type/id/ts required on every message.
        for (final field in ['zap', 'type', 'id', 'ts']) {
          expect(
            required,
            contains(field),
            reason: '$type envelope must require `$field`',
          );
        }
        final props = schema['properties'] as Map<String, dynamic>;
        final zapProp = props['zap'] as Map<String, dynamic>;
        expect(zapProp['enum'], [
          '0.1',
        ], reason: 'the zap version field is enum-bound to 0.1');
        final typeProp = props['type'] as Map<String, dynamic>;
        expect(typeProp['enum'], [
          type,
        ], reason: 'the type field is enum-bound to its own message type');
        // Unknown top-level fields are structurally rejected.
        expect(
          schema['additionalProperties'],
          false,
          reason:
              'the $type envelope is closed (hallucinated fields '
              'are schema errors)',
        );
      });
    }
  });

  group('ZapSchema — coverage (U2)', () {
    test('U2: all() covers exactly the five types, JSON-encodable', () {
      final all = ZapSchema.all;
      expect(all.keys.toSet(), {
        'mission',
        'evidence',
        'checkpoint',
        'receipt',
        'error',
      });
      for (final schema in all.values) {
        // Deep JSON-encodable (no non-JSON values smuggled in).
        expect(() => jsonEncode(schema), returnsNormally);
      }
    });

    test('U2: forType rejects unknown types', () {
      expect(() => ZapSchema.forType('telepathy'), throwsArgumentError);
    });
  });

  group('ZapSchema — the mission contract (U3)', () {
    final mission = ZapSchema.forType('mission');

    test('U3: required mission fields', () {
      final required = (mission['required'] as List).cast<String>();
      for (final field in [
        'missionId',
        'agent',
        'goal',
        'budget',
        'policy',
        'steps',
      ]) {
        expect(
          required,
          contains(field),
          reason: 'mission must require `$field` (FR-002)',
        );
      }
    });

    test('U3: budget.maxSteps is a positive integer', () {
      final props = mission['properties'] as Map<String, dynamic>;
      final budget = props['budget'] as Map<String, dynamic>;
      expect(budget['type'], 'object');
      expect(budget['additionalProperties'], false);
      expect(budget['required'], contains('maxSteps'));
      final maxSteps =
          (budget['properties'] as Map<String, dynamic>)['maxSteps']
              as Map<String, dynamic>;
      expect(maxSteps['type'], 'integer');
      expect(
        maxSteps['minimum'],
        1,
        reason: 'a zero-step budget is not a budget',
      );
    });

    test('U3: policy pins riskTier enum + allowlist shape', () {
      final props = mission['properties'] as Map<String, dynamic>;
      final policy = props['policy'] as Map<String, dynamic>;
      expect(policy['required'], contains('riskTier'));
      final policyProps = policy['properties'] as Map<String, dynamic>;
      final riskTier = policyProps['riskTier'] as Map<String, dynamic>;
      expect(riskTier['enum'], ['standard', 'elevated', 'admin']);
      final allowlist = policyProps['toolAllowlist'] as Map<String, dynamic>;
      expect(allowlist['type'], 'array');
      expect(allowlist['minItems'], 1);
      expect(allowlist['uniqueItems'], true);
    });

    test('U3: steps items require id/command/phase with the phase enum', () {
      final props = mission['properties'] as Map<String, dynamic>;
      final steps = props['steps'] as Map<String, dynamic>;
      expect(steps['type'], 'array');
      expect(steps['minItems'], 1, reason: 'an empty mission does nothing');
      final item = steps['items'] as Map<String, dynamic>;
      for (final field in ['id', 'command', 'phase']) {
        expect(
          item['required'],
          contains(field),
          reason: 'every step must carry `$field`',
        );
      }
      final itemProps = item['properties'] as Map<String, dynamic>;
      final phase = itemProps['phase'] as Map<String, dynamic>;
      expect(phase['enum'], ['red', 'green', 'refactor', 'verify']);
      final timeout = itemProps['timeoutSeconds'] as Map<String, dynamic>;
      expect(timeout['minimum'], 1);
      expect(timeout['maximum'], 600);
      expect(item['additionalProperties'], false);
    });
  });
}
