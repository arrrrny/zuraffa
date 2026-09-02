// Bug #742 regression tests — no TDD subprocess invocation may await its
// child indefinitely. Every spawn site carries a deadline: a hanging child
// is killed (SIGKILL) at the deadline, the outcome is a runnerError/timeout
// result (never a certified red, never a silent pass), and the command
// prints a clear message naming the behavior, step, and command, then exits
// non-zero. Non-timeout behavior (exit codes, summary lines) is unchanged.
//
// Fast tier: the spawned children are tiny sleep scripts (the real Dart VM),
// NOT `dart test` compiles — no fixture pub get, no build_runner.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_step_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/pipeline_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

import '../helpers/tdd_fixture.dart';

/// The deadline the tests inject. Small on purpose: the whole file must stay
/// fast-tier while still exercising REAL child processes.
const hangTimeout = Duration(seconds: 3);

/// A script that prints one line (proves partial-output capture) then never
/// returns.
Future<(Directory, String)> _sleeper() => _script(
  "import 'dart:io';\n\n"
  "void main() {\n"
  "  print('sleeper started');\n"
  "  sleep(const Duration(hours: 1));\n"
  "}",
);

/// A script that exits immediately.
Future<(Directory, String)> _quickExit() =>
    _script('void main() { print("done"); }');

Future<(Directory, String)> _script(String source) async {
  final dir = await Directory.systemTemp.createTemp('tdd_timeout_');
  final file = File('${dir.path}/child.dart');
  await file.writeAsString(source);
  return (dir, file.path);
}

void main() {
  final scratch = <Directory>[];
  Future<(Directory, String)> makeSleeper() async {
    final r = await _sleeper();
    scratch.add(r.$1);
    return r;
  }

  Future<(Directory, String)> makeQuick() async {
    final r = await _quickExit();
    scratch.add(r.$1);
    return r;
  }

  tearDown(() {
    for (final dir in scratch) {
      dir.deleteSync(recursive: true);
    }
    scratch.clear();
    exitCode = 0;
  });

  group('TddTimeouts — the per-command defaults (assessment remediation)', () {
    test('defaults are generous: 2 min single test, 10 min suite/steps', () {
      const t = TddTimeouts();
      expect(t.singleTest, const Duration(minutes: 2));
      expect(t.suite, const Duration(minutes: 10));
      expect(t.pipelineStep, const Duration(minutes: 10));
      expect(t.stepProcess, const Duration(minutes: 10));
      expect(t.refactorPass, const Duration(minutes: 10));
      expect(t.mutationPreflight, const Duration(minutes: 10));
      expect(t.mutationRun, const Duration(minutes: 30));
      expect(t.probe, const Duration(seconds: 30));
    });

    test('uniform() applies one --timeout override to every deadline', () {
      final t = TddTimeouts.uniform(const Duration(minutes: 7));
      expect(t.singleTest, const Duration(minutes: 7));
      expect(t.suite, const Duration(minutes: 7));
      expect(t.mutationRun, const Duration(minutes: 7));
      expect(t.probe, const Duration(minutes: 7));
    });

    test('parseTddTimeoutMinutes accepts minutes (fractions allowed)', () {
      expect(parseTddTimeoutMinutes(null), isNull);
      expect(parseTddTimeoutMinutes(''), isNull);
      expect(parseTddTimeoutMinutes('10'), const Duration(minutes: 10));
      expect(parseTddTimeoutMinutes('0.5'), const Duration(seconds: 30));
      expect(
        () => parseTddTimeoutMinutes('-1'),
        throwsA(isA<TddTimeoutFormatException>()),
      );
      expect(
        () => parseTddTimeoutMinutes('0'),
        throwsA(isA<TddTimeoutFormatException>()),
      );
      expect(
        () => parseTddTimeoutMinutes('abc'),
        throwsA(isA<TddTimeoutFormatException>()),
      );
    });
  });

  group('runTimed — the shared timed-spawn primitive', () {
    test('kills a child that outlives the deadline and reports it', () async {
      final (dir, sleeperPath) = await makeSleeper();
      final sw = Stopwatch()..start();
      await expectLater(
        runTimed(
          Platform.resolvedExecutable,
          [sleeperPath],
          workingDirectory: dir.path,
          timeout: hangTimeout,
        ),
        throwsA(
          isA<ProcessTimeoutException>()
              .having((e) => e.timeout, 'timeout', hangTimeout)
              .having(
                (e) => e.commandDisplay,
                'commandDisplay',
                contains(sleeperPath),
              )
              .having((e) => e.toString(), 'toString', contains('TIMED OUT')),
        ),
      );
      // The kill must bound the wait (the child would sleep for an hour).
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
    });

    test('captures the output produced before the kill', () async {
      final (dir, sleeperPath) = await makeSleeper();
      ProcessTimeoutException? caught;
      try {
        await runTimed(
          Platform.resolvedExecutable,
          [sleeperPath],
          workingDirectory: dir.path,
          timeout: hangTimeout,
        );
      } on ProcessTimeoutException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.output, contains('sleeper started'));
    });

    test('returns the ProcessResult for a child within the deadline', () async {
      final (dir, quickPath) = await makeQuick();
      final result = await runTimed(
        Platform.resolvedExecutable,
        [quickPath],
        workingDirectory: dir.path,
        timeout: const Duration(minutes: 2),
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('done'));
    });

    test(
      'still throws ProcessException when the executable cannot start',
      () async {
        await expectLater(
          runTimed(
            'definitely_not_a_real_binary_xyz_742',
            const [],
            workingDirectory: Directory.systemTemp.path,
            timeout: hangTimeout,
          ),
          throwsA(isA<ProcessException>()),
        );
      },
    );
  });

  group(
    'SingleTestRunner.runSingle (the verify-red / make single-test spawn)',
    () {
      test(
        'a hanging target test is killed and reported as a timeout',
        () async {
          final (dir, sleeperPath) = await makeSleeper();
          final runner = const SingleTestRunner();
          final sw = Stopwatch()..start();
          final record = await runner.runSingle(
            singleTemplate: '${Platform.resolvedExecutable} $sleeperPath',
            testPath: 'test/some_test.dart',
            testName: 'some behavior',
            workingDirectory: dir.path,
            timeout: hangTimeout,
          );
          expect(
            record.timedOut,
            isTrue,
            reason: 'the child hung past the deadline',
          );
          expect(record.exitCode, -1);
          expect(record.startedProcess, isTrue, reason: 'the child DID launch');
          expect(record.output, contains('TIMED OUT'));
          expect(record.output, contains(sleeperPath));
          expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
        },
      );

      test(
        'the default deadline does not fire for a normally-completing run',
        () async {
          final (dir, quickPath) = await makeQuick();
          final runner = const SingleTestRunner();
          final record = await runner.runSingle(
            singleTemplate: '${Platform.resolvedExecutable} $quickPath',
            testPath: '',
            testName: '',
            workingDirectory: dir.path,
          );
          expect(record.timedOut, isFalse);
          expect(record.exitCode, 0);
        },
      );

      test('an explicit --timeout override shortens the deadline', () async {
        final (dir, slowPath) = await _script(
          "import 'dart:io';\n\nvoid main() {\n"
          "  sleep(const Duration(seconds: 30));\n}",
        );
        scratch.add(dir);
        final runner = const SingleTestRunner();
        final sw = Stopwatch()..start();
        final record = await runner.runSingle(
          singleTemplate: '${Platform.resolvedExecutable} $slowPath',
          testPath: '',
          testName: '',
          workingDirectory: dir.path,
          timeout: const Duration(seconds: 1),
        );
        expect(record.timedOut, isTrue);
        // A 2-minute default would not have fired; the override did.
        expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
      });
    },
  );

  group('SingleTestRunner.runSuite (baseline / guard spawns)', () {
    test('a hanging full suite is killed and reported as a timeout', () async {
      final (dir, sleeperPath) = await makeSleeper();
      final runner = const SingleTestRunner();
      final record = await runner.runSuite(
        suiteTemplate: '${Platform.resolvedExecutable} $sleeperPath',
        workingDirectory: dir.path,
        timeout: hangTimeout,
      );
      expect(record.timedOut, isTrue);
      expect(record.exitCode, -1);
      expect(record.output, contains('TIMED OUT'));
    });
  });

  group('PipelineRunner.runPlan (generation pipeline spawns)', () {
    test(
      'a hanging zfa step is killed and captured as a timed-out step',
      () async {
        final (dir, sleeperPath) = await makeSleeper();
        // The pipeline invokes the entrypoint directly (a compiled zfa binary
        // shape), so the fake entrypoint is the Dart VM with the sleeper
        // script as its argument.
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: '090-tdd-fixture',
          sourceCriterion: 'FR-007',
          steps: [
            GenerationStepSpec(args: [sleeperPath], purpose: 'hang'),
          ],
        );
        final runner = const PipelineRunner();
        final result = await runner.runPlan(
          plan: plan,
          workingDirectory: dir.path,
          zfaBinOverride: Platform.resolvedExecutable,
          timeout: hangTimeout,
        );
        expect(result.completed, isFalse);
        expect(result.firstFailureIndex, 0);
        expect(result.steps.single.timedOut, isTrue);
        expect(result.steps.single.exitCode, -1);
        expect(result.steps.single.output, contains('TIMED OUT'));
      },
    );
  });

  group('StepRunner default spawn (tdd run driver steps)', () {
    test(
      'a hanging step process is killed and mapped to runner-error',
      () async {
        final (dir, sleeperPath) = await makeSleeper();
        final runner = StepRunner(zfaBin: sleeperPath, timeout: hangTimeout);
        final result = await runner.run(
          step: 'gen',
          behaviorId: 'B-001',
          feature: '090-tdd-fixture',
          projectRoot: dir.path,
        );
        expect(result.success, isFalse);
        expect(result.outcome, 'runner-error');
        expect(result.exitCode, -1);
        expect(result.output, contains('TIMED OUT'));
      },
    );
  });

  group('CorpusStepRunner default spawn (corpus driving)', () {
    test(
      'a hanging corpus step is killed and mapped to runner-error',
      () async {
        final (dir, sleeperPath) = await makeSleeper();
        final runner = CorpusStepRunner(
          zfaBin: sleeperPath,
          timeout: hangTimeout,
        );
        final result = await runner.runFeature(
          feature: '090-tdd-fixture',
          projectRoot: dir.path,
        );
        expect(result.success, isFalse);
        expect(result.outcome, 'runner-error');
        expect(result.exitCode, -1);
        expect(result.output, contains('TIMED OUT'));
      },
    );
  });

  group('DefaultProcessExecutor (refactor passes)', () {
    test('a hanging pass is killed and the registry stops on it', () async {
      final (dir, sleeperPath) = await makeSleeper();
      await Directory('${dir.path}/lib').create();
      final passes = RefactorPasses(
        dir.path,
        executor: DefaultProcessExecutor(timeout: hangTimeout),
        passSpecs: Future.value([
          RefactorPassSpec(
            name: 'build',
            command: '${Platform.resolvedExecutable} $sleeperPath',
          ),
          const RefactorPassSpec(name: 'format', command: 'true'),
        ]),
      );
      final result = await passes.run();
      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(result.actions.single.timedOut, isTrue);
      expect(result.actions.single.exitCode, -1);
      expect(result.actions.single.output, contains('TIMED OUT'));
    });
  });

  group('classify() — a timed-out single run is runnerError, never a red', () {
    test('timedOut record classifies runner-error', () {
      final record = RunRecord(
        command: 'dart test test/x_test.dart --plain-name "x"',
        exitCode: -1,
        output: 'Subprocess TIMED OUT after 2m00s',
        startedProcess: true,
        timedOut: true,
      );
      expect(classify(record), RedClassification.runnerError);
    });

    test('non-timeout classification is unchanged', () {
      final notStarted = RunRecord(
        command: 'x',
        exitCode: -1,
        output: 'Failed to start',
        startedProcess: false,
      );
      expect(classify(notStarted), RedClassification.runnerError);
      final honest = RunRecord(
        command: 'x',
        exitCode: 1,
        output: '00:00 +0 -1: x\nExpected: 42\n    Actual: 0\nTestFailure',
        startedProcess: true,
        testCount: 1,
      );
      expect(classify(honest), RedClassification.assertion);
    });
  });

  group('MutationAuditor — timeout honesty', () {
    test(
      'a timed-out preflight is NOT_ASSESSED, never preflight_red',
      () async {
        final fx = await TddFixture.create();
        scratch.add(fx.root);
        await fx.registerBehavior(id: 'B-001', description: 'returns 42');
        final auditor = MutationAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          runPreflight: (scopePaths) async => PreflightResult(
            exitCode: -1,
            output:
                'Subprocess TIMED OUT after 10m00s and was killed (SIGKILL)',
            timedOut: true,
          ),
        );
        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.notAssessed);
        expect(report.notAssessedReason, contains('timed out'));
        expect(report.mutationWasRun, isFalse);
      },
    );

    test(
      'a timed-out mutation run is NOT_ASSESSED with a clear reason',
      () async {
        final fx = await TddFixture.create();
        scratch.add(fx.root);
        await fx.registerBehavior(id: 'B-001', description: 'returns 42');
        final auditor = MutationAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          runPreflight: (scopePaths) async =>
              PreflightResult.green(exitCode: 0, output: 'green'),
          runMutation: () async => throw ProcessTimeoutException(
            executable: Platform.resolvedExecutable,
            arguments: const ['run', 'mutation_test'],
            timeout: const Duration(minutes: 30),
            workingDirectory: fx.root.path,
            output: '',
          ),
        );
        final report = await auditor.run();
        expect(report.gate, MutationGateDecision.notAssessed);
        expect(report.notAssessedReason, contains('mutation run timed out'));
      },
    );
  });

  group('CLI flag plumbing — zfa tdd verify-red --timeout', () {
    test(
      'a hanging target test stops non-zero with a timeout report',
      () async {
        final (dir, sleeperPath) = await makeSleeper();
        final fx = await TddFixture.create(
          singleTemplate: '${Platform.resolvedExecutable} $sleeperPath',
        );
        scratch.add(fx.root);
        await fx.registerBehavior(id: 'B-001', description: 'returns 42');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          'B-001',
          '--project',
          fx.root.path,
          '--timeout',
          '0.05',
        ]);
        expect(exitCode, 1);
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=runner-error '
            'certified=false feature=${fx.featureName}',
          ),
        );
        expect(out, contains('TIMED OUT'));
        expect(out, contains(sleeperPath));
        // No red evidence may be written for a timeout (never a certified red).
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      },
    );

    test('an invalid --timeout is rejected non-zero', () async {
      final fx = await TddFixture.create();
      scratch.add(fx.root);
      await fx.registerBehavior(id: 'B-001', description: 'returns 42');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        'B-001',
        '--project',
        fx.root.path,
        '--timeout',
        'abc',
      ]);
      expect(exitCode, 1);
      expect(out, contains('--timeout'));
      expect(out, contains('positive'));
    });
  });

  group('CLI flag plumbing — zfa tdd make --timeout', () {
    test(
      'a hanging pre-generation run stops non-zero as runner-error',
      () async {
        final (dir, sleeperPath) = await makeSleeper();
        final fx = await TddFixture.create(
          singleTemplate: '${Platform.resolvedExecutable} $sleeperPath',
        );
        scratch.add(fx.root);
        await fx.registerBehavior(id: 'B-001', description: 'returns 42');
        // Certified-red precondition (make refuses without it).
        await CycleLog(fx.featureDir).append(
          CycleLogEntry(
            behaviorId: 'B-001',
            kind: CycleEntryKind.red,
            runnerCommand: 'dart test',
            exitCode: 1,
            capturedOutput: 'Expected: 42\n    Actual: 0',
            classification: FailureClass.assertionFailure,
            sourceCriterion: 'FR-007',
            testPath: fx.testPathOf('B-001'),
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'make',
          'B-001',
          '--project',
          fx.root.path,
          '--timeout',
          '0.05',
        ]);
        expect(exitCode, 1);
        expect(
          out,
          contains(
            'make: behavior=B-001 outcome=runner-error '
            'feature=${fx.featureName}',
          ),
        );
        expect(out, contains('TIMED OUT'));
        expect(out, contains('re-run with a larger --timeout'));
        // No green evidence may be appended for a timed-out make.
        final log = File(fx.cycleLogPath).readAsStringSync();
        expect(log, isNot(contains('kind: green')));
      },
    );
  });
}
