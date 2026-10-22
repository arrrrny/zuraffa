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
//   4. A child that outlives the deadline is killed and the verdict keeps
//      the diagnostics bug #742 publishes (the command, the working
//      directory, the output captured before the kill).
//   5. A report the child actually wrote is trusted even when the
//      predecessor's file could not be removed.
//   6. `mutation_test` echoes the config's `<file>` text verbatim — the
//      assumption the scope backstop rests on.
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
    // A test may leave the report directory read-only (the un-removable
    // predecessor case) — restore write permission so the tree can go.
    final reportDir = Directory(p.join(tmpDir.path, outputDir));
    if (reportDir.existsSync()) {
      Process.runSync('chmod', ['755', reportDir.path]);
    }
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
        Object? failure;
        try {
          result = await verifier.run();
        } catch (e) {
          failure = e;
        }

        expect(
          report.existsSync(),
          isFalse,
          reason: 'the stale report must be removed before the child starts',
        );
        // A clean child that wrote no report is a run with NO score of
        // its own — the assertions below pin that outcome exactly. A
        // blanket catch would let an unrelated throw pass this test, so
        // the failure is named and asserted.
        expect(
          failure,
          isNull,
          reason: 'a clean child that produced no report must not throw',
        );
        expect(result, isNotNull);
        expect(result!.killedCount, 0);
        expect(result.survivedCount, 0);
        expect(result.timeoutCount, 0);
        expect(result.reportPath, isNull);
        expect(result.survivors, isEmpty);
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

    test('a child that outlives the deadline is killed, and the verdict keeps '
        'the captured diagnostics', () async {
      final report = await writeStaleReport();
      writeConfig();
      // The child hangs: `exec` hands the process over to `sleep`, so the
      // deadline kill lands on the real child.
      final fakeDart = writeFakeDart(
        '#!/bin/sh\necho "mutation run is warming up"\nexec sleep 30\n',
        'fake-dart-hanging.sh',
      );
      final verifier = MutationVerifier(
        configPath: 'mutation-test.xml',
        outputDir: outputDir,
        workingDirectory: tmpDir.path,
        timeout: const Duration(seconds: 2),
        dartBinary: fakeDart,
      );

      MutationResult? result;
      Object? failure;
      try {
        result = await verifier.run();
      } catch (e) {
        failure = e;
      }

      expect(result, isNull, reason: 'a killed run has no score');
      expect(failure, isA<MutationRunKilled>());
      final killed = failure! as MutationRunKilled;
      // The diagnostics bug #742 publishes must survive the conversion:
      // the reason names the deadline, the command and the output the
      // child produced before the kill.
      expect(killed.reason, contains('mutation run timed out'));
      expect(killed.reason, contains(fakeDart));
      expect(killed.reason, contains('mutation run is warming up'));
      // The exit code is the one the OS gave the killed child — never a
      // reconstructed one (POSIX: the signal number; Windows: the
      // TerminateProcess code).
      expect(killed.exitCode, isNotNull);
      expect(
        killed.exitCode,
        Platform.isWindows ? greaterThan(0) : -9,
        reason: 'the exit code must be the observed one',
      );
      expect(report.existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a report the child wrote is trusted even when the predecessor could '
        'not be removed', () async {
      writeConfig();
      final report = await writeStaleReport();
      // The predecessor cannot be deleted: its directory is read-only.
      // The removal fails, so the file on disk starts out untrusted —
      // but the child REWRITES it, and that report is this run's.
      final reportDir = report.parent;
      Process.runSync('chmod', ['500', reportDir.path]);
      final freshReport = '''
# Mutation report

Mutants killed: 3
Mutants survived: 1

## Undetected mutations in file : lib/tdd/002-subscription-error-vocabulary/vocab.dart
Line 7 :
''';
      final verifier = MutationVerifier(
        configPath: 'mutation-test.xml',
        outputDir: outputDir,
        workingDirectory: tmpDir.path,
        dartBinary: writeFakeDart(
          '#!/bin/sh\nchmod 755 "${reportDir.path}"\n'
              'cat > "${report.path}" <<\'REPORT\'\n${freshReport}REPORT\n',
          'fake-dart-rewrites.sh',
        ),
      );

      final result = await verifier.run();

      expect(result.reportPath, report.path);
      expect(result.killedCount, 3);
      expect(result.survivedCount, 1);
      expect(result.survivors, hasLength(1));
      expect(
        result.survivors.single.file,
        'lib/tdd/002-subscription-error-vocabulary/vocab.dart',
      );
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

  group('the scope backstop — mutation_test echoes the config <file> text', () {
    test(
      'the parsed survivor names the config\'s <file> string exactly',
      () async {
        // A real, pub-resolved fixture: one subject and one WEAK test, so
        // the mutant survives and the report carries a survivor line. This
        // is the production shape of the report — the hand-built
        // MutationResult above never exercises it.
        final root = p.join(tmpDir.path, 'fixture');
        Directory(root).createSync(recursive: true);
        File(p.join(root, 'pubspec.yaml')).writeAsStringSync('''
name: mutation_report_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
  mutation_test: ^1.8.0
''');
        File(p.join(root, 'lib', 'subject.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('int add(int a, int b) => a + b;\n');
        File(p.join(root, 'test', 'subject_test.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('''
import 'package:test/test.dart';
import 'package:mutation_report_fixture/subject.dart' as s;

void main() {
  test('a weak scope test', () {
    expect(s.add(0, 0), 0);
  });
}
''');
        final pubGet = await Process.run('dart', [
          'pub',
          'get',
        ], workingDirectory: root);
        expect(
          pubGet.exitCode,
          0,
          reason: 'fixture pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
        );

        // The scoped config the auditor writes — its `<file>` entry is the
        // scope path, verbatim.
        final config = buildScopedMutationConfig(
          subjectPaths: ['lib/subject.dart'],
          testPaths: ['test/subject_test.dart'],
          fileTemplate: 'dart test {file}',
        );
        final configFileEntry = RegExp(
          r'<file>(.*?)</file>',
        ).firstMatch(config)!.group(1)!;
        expect(configFileEntry, 'lib/subject.dart');
        File(p.join(root, 'mutation-test.xml')).writeAsStringSync(config);

        final verifier = MutationVerifier(
          configPath: 'mutation-test.xml',
          outputDir: 'mutation-report',
          workingDirectory: root,
          timeout: const Duration(minutes: 10),
        );
        final result = await verifier.run();

        expect(
          result.survivors,
          isNotEmpty,
          reason: 'the fixture must produce a survivor',
        );
        expect(result.survivors.map((s) => s.file).toSet(), {
          configFileEntry,
        }, reason: 'mutation_test must echo the config <file> text verbatim');
        expect(
          survivorsOutsideScope(result.survivors, [configFileEntry]),
          isEmpty,
          reason: 'a legitimate report must not trip the scope backstop',
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
