// Tests for the ArtifactRecord model (spec 044-test-tdd-generation, T002/T004).
//
// `ArtifactRecord` is the persisted row in `specs/<feature>/tdd/artifacts.json`
// that links a behavior id to its paired test+subject paths, runnable test
// name, ownership, and created_at. It is the durable link between `gen` and
// the later `verify` / `run` commands.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';

void main() {
  group('ArtifactRecord', () {
    final record = ArtifactRecord(
      behaviorId: 'B-003',
      feature: '044-test-tdd-generation',
      sourceCriterion: 'FR-007',
      testPath: 'test/plugins/tdd/fixtures/b003_test.dart',
      subjectPath: 'lib/src/plugins/tdd/fixtures/b003_subject.dart',
      runnableTestName:
          'test/plugins/tdd/fixtures/b003_test.dart::B-003::asserts behavior',
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
      createdAt: '2026-08-29T20:00:00Z',
    );

    test('exposes the six required fields (FR-005, FR-007)', () {
      expect(record.behaviorId, 'B-003');
      expect(record.feature, '044-test-tdd-generation');
      expect(record.sourceCriterion, 'FR-007');
      expect(record.testPath, contains('b003_test.dart'));
      expect(record.subjectPath, contains('b003_subject.dart'));
      expect(
        record.runnableTestName,
        'test/plugins/tdd/fixtures/b003_test.dart::B-003::asserts behavior',
      );
      expect(record.testOwnership, Ownership.created);
      expect(record.subjectOwnership, Ownership.created);
      expect(record.createdAt, '2026-08-29T20:00:00Z');
    });

    test('JSON round-trips losslessly (FR-007)', () {
      final encoded = jsonEncode(record.toJson());
      final decoded = ArtifactRecord.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.behaviorId, record.behaviorId);
      expect(decoded.feature, record.feature);
      expect(decoded.sourceCriterion, record.sourceCriterion);
      expect(decoded.testPath, record.testPath);
      expect(decoded.subjectPath, record.subjectPath);
      expect(decoded.runnableTestName, record.runnableTestName);
      expect(decoded.testOwnership, record.testOwnership);
      expect(decoded.subjectOwnership, record.subjectOwnership);
      expect(decoded.createdAt, record.createdAt);
    });

    test('equality is by behavior id within a feature', () {
      final same = ArtifactRecord(
        behaviorId: 'B-003',
        feature: '044-test-tdd-generation',
        sourceCriterion: 'FR-007',
        testPath: '/different/path.dart',
        subjectPath: '/different/subject.dart',
        runnableTestName: 'different::name',
        testOwnership: Ownership.reused,
        subjectOwnership: Ownership.reused,
        createdAt: '1970-01-01T00:00:00Z',
      );
      expect(
        same == record,
        isTrue,
        reason: 'equality by behavior id within a feature',
      );
      expect(same.hashCode, record.hashCode);
    });

    test('ownership diff: created test, reused subject', () {
      final r = ArtifactRecord(
        behaviorId: 'B-004',
        feature: '044-test-tdd-generation',
        sourceCriterion: 'FR-008',
        testPath: 'p.dart',
        subjectPath: 's.dart',
        runnableTestName: 'p::name',
        testOwnership: Ownership.created,
        subjectOwnership: Ownership.reused,
        createdAt: '2026-08-29T20:00:00Z',
      );
      expect(r.testOwnership, Ownership.created);
      expect(r.subjectOwnership, Ownership.reused);
    });
  });

  group(
    'issue #871 — composite parsing (descriptionSegment / plainTestName)',
    () {
      // gen's composite used to double-embed the behavior id —
      // `file::id::id — description` — so every consumer that "extracts the
      // description segment" actually received an `<id> — ` prefixed string,
      // and the tdd planner's capitalized-trace fallback captured the id as
      // the entity name (plan: `make A1` instead of `make Todo`).
      //
      // The model now owns the parsing contract: strip the record's OWN
      // behavior-id echo prefix (`<behaviorId> — `) when present, leave
      // everything else byte-identical. Legacy (double-embed) and clean
      // registries must both parse to the same description.
      ArtifactRecord record(String runnableTestName, {String id = 'A1'}) =>
          ArtifactRecord(
            behaviorId: id,
            feature: '001-crud-e2e',
            sourceCriterion: 'AC-1',
            testPath: '/proj/test/tdd/a1_test.dart',
            subjectPath: '/proj/lib/tdd/a1_subject.dart',
            runnableTestName: runnableTestName,
            testOwnership: Ownership.created,
            subjectOwnership: Ownership.created,
            createdAt: '2026-08-30T00:00:00.000Z',
          );

      test('descriptionSegment strips a legacy `<id> — ` echo prefix', () {
        final r = record(
          '/proj/test/tdd/a1_test.dart::A1::A1 — the Todo repository '
          'service persists a todo item.',
        );
        expect(
          r.descriptionSegment,
          'the Todo repository service persists a todo item.',
        );
      });

      test('descriptionSegment passes a clean composite through untouched', () {
        final r = record(
          '/proj/test/tdd/a1_test.dart::A1::the Todo repository service '
          'persists a todo item.',
        );
        expect(
          r.descriptionSegment,
          'the Todo repository service persists a todo item.',
        );
      });

      test('descriptionSegment strips ONLY the record own id echo', () {
        // A description that merely CONTAINS another id-shaped token is not
        // rewritten — only the record's own `<behaviorId> — ` prefix.
        final r = record(
          '/proj/test/tdd/u9_test.dart::U9::the U9 repository service '
          'persists an item.',
          id: 'U9',
        );
        expect(
          r.descriptionSegment,
          'the U9 repository service persists an item.',
        );
      });

      test('descriptionSegment falls back to the behavior id when the '
          'composite has no description segment', () {
        final r = record('just-a-path');
        expect(r.descriptionSegment, 'A1');
      });

      test('plainTestName strips the id echo so legacy registries still '
          'plain-name match the re-rendered test file', () {
        // --plain-name is a literal SUBSTRING matcher. Legacy pair:
        // registry `…::A1::A1 — desc`, on-disk test('A1 — desc') — the
        // stripped name `desc` is a substring of BOTH the legacy test name
        // and the re-rendered (`desc`) one, so both pair shapes match.
        final r = record(
          '/proj/test/tdd/a1_test.dart::A1::A1 — the Todo repository '
          'service persists a todo item.',
        );
        expect(
          r.plainTestName,
          'the Todo repository service persists a todo item.',
        );
      });

      test('plainTestName passes a clean composite through untouched', () {
        final r = record(
          '/proj/test/tdd/a1_test.dart::A1::the Todo repository service '
          'persists a todo item.',
        );
        expect(
          r.plainTestName,
          'the Todo repository service persists a todo item.',
        );
      });
    },
  );

  group('issue #1388 — gen_fingerprint survives every copier', () {
    // sha256-shaped digest (64 hex chars). The model treats the value as
    // opaque, but a realistic shape keeps the fixture honest about what
    // gen actually stores.
    final digest = List.filled(64, 'a').join();

    ArtifactRecord withFingerprint(String? genFingerprint) => ArtifactRecord(
      behaviorId: 'B-003',
      feature: '044-test-tdd-generation',
      sourceCriterion: 'FR-007',
      testPath: 'test/plugins/tdd/fixtures/b003_test.dart',
      subjectPath: 'lib/src/plugins/tdd/fixtures/b003_subject.dart',
      runnableTestName:
          'test/plugins/tdd/fixtures/b003_test.dart::B-003::asserts behavior',
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
      createdAt: '2026-08-29T20:00:00Z',
      genFingerprint: genFingerprint,
    );

    // Every copier that must carry the digest forward, keyed by the copier
    // under test. Adding a copier to the model is ONE row here — the loop
    // below is the whole expectation set, so a new copy site that forgets
    // the OPTIONAL field fails loudly instead of dropping the digest.
    final copiers = <String, ArtifactRecord Function(ArtifactRecord)>{
      'copyWithOwnership': (r) => r.copyWithOwnership(
        testOwnership: Ownership.reused,
        subjectOwnership: Ownership.reused,
      ),
      'copyWithGenFingerprint': (r) => r.copyWithGenFingerprint(digest),
    };

    test('an absent gen_fingerprint key decodes to null and toJson omits it '
        '— legacy registries stay byte-stable', () {
      final legacy = withFingerprint(null);
      expect(legacy.genFingerprint, isNull);

      final json = legacy.toJson();
      expect(
        json.containsKey('gen_fingerprint'),
        isFalse,
        reason:
            'a pre-#1388 registry must round-trip byte-for-byte through '
            'load/save cycles',
      );
      expect(jsonEncode(json), isNot(contains('gen_fingerprint')));

      final decoded = ArtifactRecord.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(decoded.genFingerprint, isNull);
      expect(jsonEncode(decoded.toJson()), jsonEncode(json));
    });

    test('a present digest round-trips fromJson -> toJson unchanged', () {
      final json = withFingerprint(digest).toJson();
      expect(json['gen_fingerprint'], digest);

      final decoded = ArtifactRecord.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(decoded.genFingerprint, digest);
      expect(jsonEncode(decoded.toJson()), jsonEncode(json));
    });

    for (final entry in copiers.entries) {
      test('${entry.key} preserves the stored digest', () {
        final copied = entry.value(withFingerprint(digest));
        expect(
          copied.genFingerprint,
          digest,
          reason:
              '${entry.key} dropped gen_fingerprint: a copy site that '
              'forgets the OPTIONAL field still compiles, so the digest '
              'vanishes silently and reopens issue #1388',
        );
      });
    }

    test('copyWithGenFingerprint replaces or clears the digest', () {
      final other = List.filled(64, 'b').join();
      final replaced = withFingerprint(digest).copyWithGenFingerprint(other);
      expect(replaced.genFingerprint, other);

      final cleared = replaced.copyWithGenFingerprint(null);
      expect(cleared.genFingerprint, isNull);
      expect(cleared.toJson().containsKey('gen_fingerprint'), isFalse);
    });
  });
}
