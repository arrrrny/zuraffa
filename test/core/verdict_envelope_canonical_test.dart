// SPEC 1105 — one canonical `--json` envelope: `zuraffa.verdict.v1`.
//
// The A+ sweep landed --json envelopes on most generator commands but the
// shapes drifted (schema:1 integers, "zuraffa.verdict.v1", cache.verify.v1 ad-hoc).
// This file pins the ONE canonical contract:
//
//   * the schema identifier is exactly `zuraffa.verdict.v1`;
//   * `VerdictEnvelope.fromJson` parses every emitter's output and THROWS
//     (loudly) on a schema mismatch — old parsers must never fail silent;
//   * toJson → fromJson → toJson round-trips are stable;
//   * the parser accepts every field the 7 migrated emitters emit
//     (including the tdd grandfathered forms: exit_class label, feature,
//     fix, verdict `stopped`).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';

void main() {
  group('SPEC 1105: canonical schema id', () {
    test('U1: the schema constant is exactly "zuraffa.verdict.v1"', () {
      expect(VerdictEnvelope.canonicalSchema, 'zuraffa.verdict.v1');
    });

    test('U2: toJson always carries the canonical schema key', () {
      final envelope = VerdictEnvelope(
        command: 'zfa route create Product',
        verdict: VerdictKind.pass,
        exitClass: 0,
      );
      expect(envelope.toJson()['schema'], 'zuraffa.verdict.v1');
    });
  });

  group('SPEC 1105: fromJson — the one parser', () {
    test('U3: parses a full canonical envelope (every field)', () {
      final doc = {
        'schema': 'zuraffa.verdict.v1',
        'command': 'zfa route create Product',
        'verdict': 'pass',
        'exit_class': 0,
        'subject': {'kind': 'route', 'id': 'Product'},
        'artifacts': {
          'created': ['lib/src/routing/product_routes.dart'],
          'modified': ['android/app/src/main/AndroidManifest.xml'],
          'deleted': <String>[],
        },
        'receipts': ['.zfa/receipts/routes-Product.json'],
        'findings': [
          {
            'kind': 'route-builder-missing',
            'fix': 'zfa route create Product',
            'file': 'lib/src/routing/product_routes.dart',
            'member': '/product/:id',
            'detail': 'route has no builder',
          },
        ],
        'drifts': <String>[],
        'details': {'routes': <Map<String, dynamic>>[]},
        'timestamp': '2026-09-05T12:00:00.000Z',
      };

      final envelope = VerdictEnvelope.fromJson(doc);

      expect(envelope.command, 'zfa route create Product');
      expect(envelope.verdict, VerdictKind.pass);
      expect(envelope.exitClass, 0);
      expect(envelope.subject?.kind, 'route');
      expect(envelope.subject?.id, 'Product');
      expect(envelope.artifacts.created, isNotEmpty);
      expect(envelope.artifacts.modified, isNotEmpty);
      expect(envelope.artifacts.deleted, isEmpty);
      expect(envelope.receipts, ['.zfa/receipts/routes-Product.json']);
      expect(envelope.findings, hasLength(1));
      expect(envelope.findings.first.kind, 'route-builder-missing');
      expect(envelope.findings.first.fix, 'zfa route create Product');
      expect(
        envelope.findings.first.file,
        'lib/src/routing/product_routes.dart',
      );
      expect(envelope.findings.first.member, '/product/:id');
      expect(envelope.findings.first.extra['detail'], 'route has no builder');
      expect(envelope.drifts, isEmpty);
      expect(envelope.details['routes'], isA<List>());
      expect(envelope.timestamp, DateTime.utc(2026, 9, 5, 12));
    });

    test('U4: schema mismatch throws LOUDLY (old parsers break, not lie)', () {
      // Each drifted shape the A+ sweep produced.
      for (final badSchema in const [
        1, // the schema:1 integer family
        'verdict.v1', // the tdd pre-1105 name
        'cache.verify.v1', // ad-hoc
        'route.v1', // ad-hoc
        'repository-contract.v1', // ad-hoc
        null, // missing
      ]) {
        expect(
          () => VerdictEnvelope.fromJson({
            'schema': badSchema,
            'command': 'zfa cache verify Product',
            'verdict': 'pass',
          }),
          throwsA(isA<VerdictSchemaException>()),
          reason: 'schema `$badSchema` must break loudly',
        );
      }
    });

    test('U5: an invalid verdict value throws (no silent lies)', () {
      expect(
        () => VerdictEnvelope.fromJson({
          'schema': 'zuraffa.verdict.v1',
          'command': 'zfa tdd run',
          'verdict': 'maybe',
        }),
        throwsA(isA<VerdictSchemaException>()),
      );
    });

    test('U6: a missing command throws (the envelope names its producer)', () {
      expect(
        () => VerdictEnvelope.fromJson({
          'schema': 'zuraffa.verdict.v1',
          'verdict': 'pass',
        }),
        throwsA(isA<VerdictSchemaException>()),
      );
    });

    test('U7: accepts the tdd grandfathered forms (label exit_class, '
        'feature, fix, verdict stopped)', () {
      final envelope = VerdictEnvelope.fromJson({
        'schema': 'zuraffa.verdict.v1',
        'command': 'run',
        'feature': 'product_detail',
        'verdict': 'stopped',
        'exit_class': 'stopped',
        'fix': 'zfa tdd plan product_detail',
        'drifts': ['lib/src/features/x.dart'],
        'details': {'red': 1},
        'timestamp': '2026-09-05T12:00:00.000Z',
      });

      expect(envelope.verdict, VerdictKind.stopped);
      expect(envelope.exitClass, isNull);
      expect(envelope.exitClassLabel, 'stopped');
      expect(envelope.feature, 'product_detail');
      expect(envelope.fix, 'zfa tdd plan product_detail');
      expect(envelope.drifts, ['lib/src/features/x.dart']);
    });

    test('U8: emits the label form it parsed (round-trip honesty)', () {
      final envelope = VerdictEnvelope.fromJson({
        'schema': 'zuraffa.verdict.v1',
        'command': 'run',
        'verdict': 'stopped',
        'exit_class': 'stopped',
        'timestamp': '2026-09-05T12:00:00.000Z',
      });
      expect(envelope.toJson()['exit_class'], 'stopped');
    });
  });

  group('SPEC 1105: round-trip stability', () {
    test('U9: toJson → fromJson → toJson is byte-stable (int exit_class)', () {
      final envelope = VerdictEnvelope(
        command: 'zfa state create --name Product',
        verdict: VerdictKind.pass,
        exitClass: 0,
        subject: const VerdictSubject(kind: 'state', id: 'Product'),
        artifacts: const VerdictArtifacts(
          created: ['lib/src/state/product_state.dart'],
        ),
        receipts: const ['.zfa/receipts/state-create-Product-1.json'],
        details: const {
          'fields': ['id', 'name'],
          'flavor': 'pureDart',
        },
        timestamp: DateTime.utc(2026, 9, 5, 12),
      );

      final once = envelope.toJsonLine();
      final twice = VerdictEnvelope.fromJson(
        jsonDecode(once) as Map<String, dynamic>,
      ).toJsonLine();

      expect(twice, once);
    });

    test('U10: toJson → fromJson → toJson is byte-stable (label form)', () {
      final envelope = VerdictEnvelope(
        command: 'gen',
        verdict: VerdictKind.fail,
        exitClassLabel: 'fail',
        drifts: const ['a.dart', 'b.dart'],
        timestamp: DateTime.utc(2026, 9, 5, 12),
      );

      final once = envelope.toJsonLine();
      final twice = VerdictEnvelope.fromJson(
        jsonDecode(once) as Map<String, dynamic>,
      ).toJsonLine();

      expect(twice, once);
    });
  });

  group('SPEC 1105: mixed-stream extraction (MCP boundary seam)', () {
    test('U11: tryParse finds the envelope as the last stdout line', () {
      final output =
          '✅ route create: Product\n'
          '  ✨ lib/src/routing/product_routes.dart (created)\n'
          '{"schema":"zuraffa.verdict.v1","command":"zfa route create Product",'
          '"verdict":"pass","exit_class":0,"details":{},'
          '"timestamp":"2026-09-05T12:00:00.000Z"}';

      final envelope = VerdictEnvelope.tryParse(output);

      expect(envelope, isNotNull);
      expect(envelope!.command, 'zfa route create Product');
      expect(envelope.verdict, VerdictKind.pass);
    });

    test('U12: tryParse returns null for text-only or foreign-JSON output', () {
      expect(VerdictEnvelope.tryParse('no json here'), isNull);
      expect(
        VerdictEnvelope.tryParse('{"schema": 1, "verdict": "pass"}'),
        isNull,
        reason: 'a drifted shape is NOT a canonical envelope',
      );
    });
  });
}
