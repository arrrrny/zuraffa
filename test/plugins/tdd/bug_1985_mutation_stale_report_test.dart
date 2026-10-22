// Bug #1985 — a killed mutation run must not inherit the previous
// feature's report.
//
// The mutation report path is per WORKING DIRECTORY
// (`.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`), not per
// feature: the previous feature's verify run left its report there. A
// mutation child that is killed at the deadline never rewrites the
// report, so the stale file was parsed as this run's score — the
// verification record published ANOTHER feature's numbers, with a
// survivor list naming files outside its own scope.
//
// The contract pinned here:
//   1. The stale report is removed BEFORE the mutation child starts.
//   2. A child killed by a signal publishes NO score — the gate is
//      `not_assessed` carrying the child's exit code.
//   3. A survivor list naming a file outside the recorded scope means the
//      report does not belong to this run — `not_assessed`, never a score.
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

  /// The report a PREVIOUS feature's verify run left behind: its counts
  /// and its survivor list name `lib/tdd/001-purchase-store/…`, a file
  /// outside any other feature's scope.
  const staleReport = '''
# Mutation report

Mutants killed: 77
Mutants survived: 79
Mutants timed out: 0

## Undetected mutations in file : lib/tdd/001-purchase-store/store.dart
Line 12 :
''';

  const outputDir = '.dart_tool/zfa/tdd-verify-report';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1985_mutation_stale_');
    featureDir = '${tmpDir.path}/specs/002-subscription-error-vocabulary';
    registry = ArtifactRegistry(featureDir: featureDir);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ArtifactRecord sampleRecord({
    String behaviorId = 'B-001',
    String subjectPath = 'lib/tdd/002-subscription-error-vocabulary/vocab.dart',
  }) => ArtifactRecord(
    behaviorId: behaviorId,
    feature: '002-subscription-error-vocabulary',
    sourceCriterion: 'FR-018',
    testPath: 'test/tdd/002_subscription_error_vocabulary_test.dart',
    subjectPath: subjectPath,
    runnableTestName: '$behaviorId::asserts behavior',
    testOwnership: Ownership.created,
    subjectOwnership: Ownership.created,
    createdAt: '2026-10-20T20:00:00Z',
  );

  /// Writes an executable stub that stands in for `dart run mutation_test`
  /// so the child's fate is deterministic (a clean exit, a signal death).
  String writeFakeDart(String script, String name) {
    final file = File(p.join(tmpDir.path, name))..writeAsStringSync(script);
    Process.runSync('chmod', ['+x', file.path]);
    return file.path;
  }

  Future<File> writeStaleReport() async {
    final report = File(
      p.join(tmpDir.path, outputDir, 'mutation-test-report.md'),
    );
    await report.parent.create(recursive: true);
    await report.writeAsString(staleReport);
    return report;
  }

  void writeConfig() {
    File(p.join(tmpDir.path, 'mutation-test.xml')).writeAsStringSync(
      '<mutations version="1.0">\n  <files>\n  </files>\n'
      '  <commands>\n  </commands>\n</mutations>\n',
    );
  }

  group('MutationVerifier — a stale report is never inherited', () {
    test(
      'the previous run\'s report is removed before the child starts',
      () async {
        final report = await writeStaleReport();
        writeConfig();
        // The child finishes cleanly but writes NO report — the state a
        // killed run leaves behind.
        final verifier = MutationVerifier(
          configPath: 'mutation-test.xml',
          outputDir: outputDir,
          workingDirectory: tmpDir.path,
          dartBinary: writeFakeDart('#!/bin/sh\nexit 0\n', 'fake-dart.sh'),
        );

        MutationResult? result;
        try {
          result = await verifier.run();
        } catch (_) {
          // A failure to produce a report is an acceptable outcome; the
          // assertions below pin that no score was inherited.
        }

        expect(
          report.existsSync(),
          isFalse,
          reason: 'the stale report must be removed before the child starts',
        );
        expect(result?.killedCount, isNot(77));
        expect(result?.survivedCount, isNot(79));
        expect(result?.survivors, isEmpty);
      },
    );

    test('a child killed by a signal publishes no score', () async {
      final report = await writeStaleReport();
      writeConfig();
      // SIGTERM to itself — the child dies with exit code -15, exactly
      // the shape of the run that produced the issue's record.
      final verifier = MutationVerifier(
        configPath: 'mutation-test.xml',
        outputDir: outputDir,
        workingDirectory: tmpDir.path,
        dartBinary: writeFakeDart(
          '#!/bin/sh\nkill -TERM \$\$\n',
          'fake-dart-killed.sh',
        ),
      );

      MutationResult? result;
      Object? failure;
      try {
        result = await verifier.run();
      } catch (e) {
        failure = e;
      }

      expect(
        result,
        isNull,
        reason: 'a killed run has no score — it must not report one',
      );
      expect(failure, isA<MutationRunKilled>());
      expect((failure! as MutationRunKilled).exitCode, -15);
      expect(report.existsSync(), isFalse);
    });
  });

  group('MutationAuditor — a killed run is not_assessed', () {
    Future<void> registerFeature() async {
      await registry.register(sampleRecord());
      final subject = File(
        p.join(
          tmpDir.path,
          'lib/tdd/002-subscription-error-vocabulary/vocab.dart',
        ),
      );
      await subject.parent.create(recursive: true);
      await subject.writeAsString('library;');
    }

    test(
      'a killed mutation run is NOT_ASSESSED and carries the exit code',
      () async {
        await registerFeature();
        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'green'),
          runMutation: () async => throw MutationRunKilled(
            'mutation run killed by signal 15 (exit code -15) — the child '
            'never finished, so no mutation score can be published',
            exitCode: -15,
          ),
        );

        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.notAssessed);
        expect(report.exitCode, -15);
        expect(report.mutationScore, isNull);
        expect(report.survivors, isEmpty);
        expect(report.notAssessedReason, contains('killed'));
      },
    );

    test('a survivor outside the recorded scope is NOT_ASSESSED — the report '
        'belongs to another run', () async {
      await registerFeature();
      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'green'),
        // The previous feature's numbers, with the previous feature's
        // survivors.
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 77,
          survivedCount: 79,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 1),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 77, survived 79',
          stderrText: '',
          survivors: const [
            MutationSurvivor(
              file: 'lib/tdd/001-purchase-store/store.dart',
              line: 12,
            ),
          ],
        ),
      );

      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.notAssessed);
      expect(report.mutationScore, isNull);
      expect(report.survivors, isEmpty);
      expect(report.notAssessedReason, contains('outside the recorded scope'));
    });

    test('a survivor inside the recorded scope still fails the gate', () async {
      await registerFeature();
      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'green'),
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 9,
          survivedCount: 1,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 1),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 9, survived 1',
          stderrText: '',
          survivors: const [
            MutationSurvivor(
              file: 'lib/tdd/002-subscription-error-vocabulary/vocab.dart',
              line: 12,
            ),
          ],
        ),
      );

      final report = await auditor.run();
      expect(report.gate, MutationGateDecision.failSurvived);
      expect(report.mutationScore, closeTo(0.9, 1e-9));
      expect(report.survivors, hasLength(1));
    });
  });
}
