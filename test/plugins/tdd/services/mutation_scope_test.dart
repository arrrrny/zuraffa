// Tests for the MutationScope service (spec 044-test-tdd-generation,
// T028/T029–T030).
//
// `MutationScope` derives the union of test+subject paths from
// `specs/<feature>/tdd/artifacts.json`. When no behavior artifacts are
// registered, it returns `NOT_ASSESSED — no behavior artifacts registered`
// (FR-012).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_scope.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late ArtifactRegistry registry;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('mutation_scope_test_');
    featureDir = '${tmpDir.path}/specs/044-test-tdd-generation';
    registry = ArtifactRegistry(featureDir: featureDir);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ArtifactRecord sampleRecord({
    String behaviorId = 'B-003',
    String sourceCriterion = 'FR-007',
    String testPath = 'test/b003_test.dart',
    String subjectPath = 'lib/b003_subject.dart',
  }) => ArtifactRecord(
    behaviorId: behaviorId,
    feature: '044-test-tdd-generation',
    sourceCriterion: sourceCriterion,
    testPath: testPath,
    subjectPath: subjectPath,
    runnableTestName: '$testPath::$behaviorId::asserts behavior',
    testOwnership: Ownership.created,
    subjectOwnership: Ownership.created,
    createdAt: '2026-08-29T20:00:00Z',
  );

  group('MutationScope', () {
    test(
      'derives the union of test+subject paths from artifacts.json (FR-012)',
      () async {
        await registry.register(
          sampleRecord(
            behaviorId: 'B-001',
            sourceCriterion: 'FR-001',
            testPath: 'test/b001_test.dart',
            subjectPath: 'lib/b001_subject.dart',
          ),
        );
        await registry.register(
          sampleRecord(
            behaviorId: 'B-002',
            sourceCriterion: 'FR-005',
            testPath: 'test/b002_test.dart',
            subjectPath: 'lib/b002_subject.dart',
          ),
        );

        final scope = await MutationScope.derive(featureDir: featureDir);
        expect(scope.subjectPaths, contains('lib/b001_subject.dart'));
        expect(scope.subjectPaths, contains('lib/b002_subject.dart'));
        expect(scope.testPaths, contains('test/b001_test.dart'));
        expect(scope.testPaths, contains('test/b002_test.dart'));
        expect(scope.behaviorIds, contains('B-001'));
        expect(scope.behaviorIds, contains('B-002'));
        expect(scope.isEmpty, isFalse);
      },
    );

    test(
      'no registered artifacts → NOT_ASSESSED — no behavior artifacts registered (FR-012)',
      () async {
        // No artifacts.json file exists yet.
        final scope = await MutationScope.derive(featureDir: featureDir);
        expect(scope.isEmpty, isTrue);
        // The MutationAuditor will translate empty scope into NOT_ASSESSED.
        // Verify the scope carries enough state for that translation.
        expect(scope.subjectPaths, isEmpty);
        expect(scope.testPaths, isEmpty);
        expect(scope.behaviorIds, isEmpty);
        expect(
          scope.notAssessedReason,
          contains('no behavior artifacts registered'),
        );
      },
    );

    test(
      'scope exposes behaviorId → sourceCriterion map for the report (FR-018)',
      () async {
        await registry.register(
          sampleRecord(behaviorId: 'B-009', sourceCriterion: 'FR-010'),
        );
        final scope = await MutationScope.derive(featureDir: featureDir);
        expect(scope.sourceCriterionFor('B-009'), 'FR-010');
      },
    );
  });
}
