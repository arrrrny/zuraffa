// Tests for the MutationAuditor service (spec 044-test-tdd-generation,
// T034/T035–T042).
//
// The auditor wraps the existing `MutationVerifier` with the behavior-traced,
// scope-derived, NOT_ASSESSED, source-restoration flow required by
// FR-012..021. These tests cover the unit-level behaviors with synthetic
// MutationVerifier implementations (no real `dart run mutation_test`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late ArtifactRegistry registry;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('mutation_auditor_test_');
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

  Future<File> writeSubject(String rel, String content) async {
    final f = File(p.join(tmpDir.path, rel));
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
    return f;
  }

  group('MutationAuditor', () {
    test(
      'preflight FIRST: red preflight → PREFLIGHT_RED, no mutation (FR-013)',
      () async {
        // Register an artifact for which the subject exists but the
        // paired test fails (preflight red).
        final subjectFile = await writeSubject(
          'lib/b003_subject.dart',
          'library;',
        );
        final record = sampleRecord(
          subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
          testPath: 'test/b003_test.dart',
        );
        await registry.register(record);
        // The test file does NOT exist on disk → `dart test` preflight fails.

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.red(exitCode: 1, output: 'preflight failed'),
          runMutation: () async => throw UnimplementedError('should not run'),
        );

        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.preflightRed);
        expect(report.mutationWasRun, isFalse);
      },
    );

    test(
      'tool unavailable → NOT_ASSESSED — mutation tool unavailable (FR-015)',
      () async {
        final subjectFile = await writeSubject(
          'lib/b003_subject.dart',
          'library;',
        );
        final record = sampleRecord(
          subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
        );
        await registry.register(record);

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'all tests passed'),
          runMutation: () async =>
              throw MutationToolUnavailable('`dart` binary not found on PATH'),
        );

        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.notAssessed);
        expect(report.notAssessedReason, contains('mutation tool unavailable'));
        expect(report.killedCount, 0);
        expect(report.survivedCount, 0);
        expect(report.timedOutCount, 0);
      },
    );

    test(
      'empty/incomplete/unparseable report → NOT_ASSESSED (FR-016)',
      () async {
        final subjectFile = await writeSubject(
          'lib/b003_subject.dart',
          'library;',
        );
        final record = sampleRecord(
          subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
        );
        await registry.register(record);

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: ''),
          // Mutation ran but produced a non-parseable report.
          runMutation: () async => MutationResult(
            exitCode: 0,
            killedCount: 0,
            survivedCount: 0,
            timeoutCount: 0,
            elapsed: Duration.zero,
            reportPath: null,
            stdoutText: 'mutation_test ran but the report was truncated',
            stderrText: '',
          ),
        );

        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.notAssessed);
        // The auditor classifies "all buckets zero AND no report path" as
        // NOT_ASSESSED rather than PASS.
        expect(report.notAssessedReason, isNotNull);
      },
    );

    test(
      'killed/survived/timed-out recorded as three separate buckets (FR-014)',
      () async {
        final subjectFile = await writeSubject(
          'lib/b003_subject.dart',
          'library;',
        );
        final record = sampleRecord(
          subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
        );
        await registry.register(record);

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: ''),
          runMutation: () async => MutationResult(
            exitCode: 1,
            killedCount: 4,
            survivedCount: 2,
            timeoutCount: 1,
            elapsed: const Duration(seconds: 10),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 4, survived 2, timeout 1',
            stderrText: '',
          ),
        );

        final report = await auditor.run();
        expect(report.killedCount, 4);
        expect(report.survivedCount, 2);
        expect(report.timedOutCount, 1);
        // Three separate buckets in the report.
        expect(report.toMarkdown(), contains('killed: 4'));
        expect(report.toMarkdown(), contains('survived: 2'));
        expect(report.toMarkdown(), contains('timed_out: 1'));
      },
    );

    test('strict policy: survived → FAIL_SURVIVED (FR-017)', () async {
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 5,
          survivedCount: 1,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 10),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 5, survived 1',
          stderrText: '',
        ),
      );

      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.failSurvived);
    });

    test('strict policy: timeout-only → FAIL_TIMEOUT (FR-017)', () async {
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 5,
          survivedCount: 0,
          timeoutCount: 1,
          elapsed: const Duration(seconds: 10),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 5, survived 0, timeout 1',
          stderrText: '',
        ),
      );

      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.failTimeout);
    });

    test('all killed → PASS (FR-017)', () async {
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => MutationResult(
          exitCode: 0,
          killedCount: 10,
          survivedCount: 0,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 30),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 10',
          stderrText: '',
        ),
      );

      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.pass);
    });

    test(
      'report traces outcome to behavior id + source criterion (FR-018)',
      () async {
        final subjectFile = await writeSubject(
          'lib/b003_subject.dart',
          'library;',
        );
        final record = sampleRecord(
          behaviorId: 'B-003',
          sourceCriterion: 'FR-007',
          subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
        );
        await registry.register(record);

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: ''),
          runMutation: () async => MutationResult(
            exitCode: 1,
            killedCount: 5,
            survivedCount: 1,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 10),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 5, survived 1',
            stderrText: '',
          ),
        );

        final report = await auditor.run();
        final md = report.toMarkdown();
        expect(md, contains('B-003'));
        expect(md, contains('FR-007'));
      },
    );

    test('source restoration verified by sha256 post-audit (FR-021)', () async {
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final originalContent = await subjectFile.readAsString();
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      // The mutation runner mutates the file in-place; restoration must
      // bring it back.
      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async {
          // Simulate a mutation: temporarily rewrite the subject.
          await subjectFile.writeAsString('// MUTATED');
          return MutationResult(
            exitCode: 1,
            killedCount: 5,
            survivedCount: 1,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 10),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 5, survived 1',
            stderrText: '',
          );
        },
      );

      final report = await auditor.run();
      // After the audit, the subject is restored.
      final restoredContent = await subjectFile.readAsString();
      expect(restoredContent, originalContent);
      expect(report.restorationVerified, isTrue);
    });

    test('never edits a test to fake a pass (FR-022)', () async {
      // The auditor is read-only on test files. We verify this structurally:
      // the auditor only restores subject files, never test files. The
      // auditor's restore scope is exactly the subject paths from the
      // registry, never the test paths.
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final testFile = await writeSubject(
        'test/b003_test.dart',
        '// user test',
      );
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
        testPath: p.relative(testFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      final originalTestContent = await testFile.readAsString();

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async {
          // Simulate a malicious mutation tool that tries to edit the test
          // file to fake a pass.
          await testFile.writeAsString('// MUTATED BY AUDIT');
          return MutationResult(
            exitCode: 0,
            killedCount: 10,
            survivedCount: 0,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 10),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 10',
            stderrText: '',
          );
        },
      );

      final report = await auditor.run();
      // The auditor must NOT restore test files (it doesn't touch them).
      // But the audit also must NOT have been able to fake a pass by
      // editing the test: the auditor's `run` only mutates subjects.
      // The test file content should be whatever the malicious tool left
      // it as — the auditor's contract is to never touch tests, not to
      // defend against a malicious tool that does.
      //
      // The point of FR-022 is: the auditor itself NEVER edits a test.
      // The auditor's restore scope is subject files only.
      expect(report.restorationScope, isNot(contains(testFile.path)));
      expect(report.restorationScope, contains(subjectFile.path));
      // Use statement for clarity.
      expect(originalTestContent, isNotNull);
    });

    test('no behavior artifacts registered → NOT_ASSESSED (FR-012)', () async {
      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => throw UnimplementedError('should not run'),
      );
      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.notAssessed);
      expect(
        report.notAssessedReason,
        contains('no behavior artifacts registered'),
      );
      expect(report.mutationWasRun, isFalse);
    });

    test('non-sensitive repro diagnostics (FR-020)', () async {
      final subjectFile = await writeSubject(
        'lib/b003_subject.dart',
        'library;',
      );
      final record = sampleRecord(
        subjectPath: p.relative(subjectFile.path, from: tmpDir.path),
      );
      await registry.register(record);

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 5,
          survivedCount: 1,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 42),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 5, survived 1',
          stderrText: '',
        ),
      );

      final report = await auditor.run();
      final md = report.toMarkdown();
      // Must include runner command, exit code, elapsed, report path.
      expect(md, contains('runner_command:'));
      expect(md, contains('exit_code:'));
      expect(md, contains('elapsed_seconds:'));
      expect(md, contains('42'));
      expect(md, contains('report_path:'));
      // Must NOT include secrets.
      expect(md, isNot(contains('github_pat_')));
      expect(md, isNot(contains('Bearer ')));
    });
  });
}
