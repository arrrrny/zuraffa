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

    test('binaryMtime round-trips losslessly (bug #683)', () {
      final stamped = record.copyWithBinaryMtime('2026-09-01T14:09:44.000Z');
      expect(stamped.binaryMtime, '2026-09-01T14:09:44.000Z');
      final decoded = ArtifactRecord.fromJson(
        jsonDecode(jsonEncode(stamped.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.binaryMtime, '2026-09-01T14:09:44.000Z');
    });

    test('legacy JSON without binary_mtime deserializes with null '
        '(backwards compatible, bug #683)', () {
      final legacy = Map<String, dynamic>.from(record.toJson())
        ..remove('binary_mtime');
      final decoded = ArtifactRecord.fromJson(legacy);
      expect(decoded.binaryMtime, isNull);
      // Ownership copies preserve a null binaryMtime.
      final copied = decoded.copyWithOwnership(
        testOwnership: Ownership.reused,
        subjectOwnership: Ownership.reused,
      );
      expect(copied.binaryMtime, isNull);
    });
  });
}
