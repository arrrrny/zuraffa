// Tests for `PipelineRunner` (spec 047-tdd-make T006/T009,
// U8-U13 / FR-006).
//
// Drives the runner against a fake `zfa` shell script written by
// [TddFixture.writeFakeZfaBin], so each step's command / exit code /
// output is observable and reproducible.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/pipeline_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
  });

  group('PipelineRunner (T006 / FR-006)', () {
    test('U8: steps execute in plan order', () async {
      final logPath = fx.fakeZfaLogPath;
      final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);

      const runner = PipelineRunner();
      final plan = GenerationPlan(
        behaviorId: 'B-001',
        feature: fx.featureName,
        sourceCriterion: 'FR-006',
        steps: [
          GenerationStepSpec(args: ['entity', 'create', 'User'], purpose: 'p1'),
          GenerationStepSpec(args: ['make', 'User'], purpose: 'p2'),
          GenerationStepSpec(args: ['build'], purpose: 'p3'),
        ],
      );
      final result = await runner.runPlan(
        plan: plan,
        workingDirectory: fx.root.path,
        zfaBinOverride: zfaBin,
      );
      expect(result.completed, isTrue);
      expect(result.steps, hasLength(3));
      // Order: argv lines in the log should be in plan order.
      final log = await fx.readFakeZfaLog();
      expect(log, hasLength(3));
      expect(log[0], contains('entity create User'));
      expect(log[1], contains('make User'));
      expect(log[2], contains('build'));
    });

    test(
      'U9: every executed step is captured with command, exit code, output',
      () async {
        final logPath = fx.fakeZfaLogPath;
        final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);

        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            GenerationStepSpec(
              args: ['entity', 'create', 'User'],
              purpose: 'p1',
            ),
            GenerationStepSpec(args: ['build'], purpose: 'p2'),
          ],
        );
        final result = await runner.runPlan(
          plan: plan,
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        for (final step in result.steps) {
          expect(step.command, isNotEmpty);
          expect(step.exitCode, 0);
          expect(step.purpose, isNotEmpty);
          // Output captured (the fake script doesn't print but the
          // capture path is exercised).
          expect(step.output, isNotNull);
        }
        expect(result.entrypoint, zfaBin);
      },
    );

    test(
      'U10: the first failing step stops the plan; later steps never execute',
      () async {
        final logPath = fx.fakeZfaLogPath;
        // First invocation (`entity create`) exits 1; the plan must stop.
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: logPath,
          exitByArgv: {'entity create': 1},
        );

        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            GenerationStepSpec(
              args: ['entity', 'create', 'User'],
              purpose: 'p1',
            ),
            GenerationStepSpec(args: ['build'], purpose: 'p2'),
          ],
        );
        final result = await runner.runPlan(
          plan: plan,
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        expect(result.completed, isFalse);
        expect(result.firstFailureIndex, 0);
        // Only the failing step was captured; the second never ran.
        expect(result.steps, hasLength(1));
        final log = await fx.readFakeZfaLog();
        expect(log, hasLength(1));
        expect(log[0], contains('entity create'));
      },
    );

    test('U11: --zfa-bin overrides entrypoint auto-resolution', () async {
      final logPath = fx.fakeZfaLogPath;
      final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);

      const runner = PipelineRunner();
      final plan = GenerationPlan(
        behaviorId: 'B-001',
        feature: fx.featureName,
        sourceCriterion: 'FR-006',
        steps: [
          GenerationStepSpec(args: ['build'], purpose: 'p1'),
        ],
      );
      final result = await runner.runPlan(
        plan: plan,
        workingDirectory: fx.root.path,
        zfaBinOverride: zfaBin,
      );
      expect(result.completed, isTrue);
      expect(result.entrypoint, zfaBin);
    });

    test(
      'U12: an unresolvable entrypoint stops before any step executes',
      () async {
        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            GenerationStepSpec(args: ['build'], purpose: 'p1'),
          ],
        );
        // Point at a path that does not exist on disk.
        expect(
          () => runner.runPlan(
            plan: plan,
            workingDirectory: fx.root.path,
            zfaBinOverride: p.join(fx.root.path, 'does_not_exist.sh'),
          ),
          throwsA(isA<PipelineResolutionError>()),
        );
      },
    );

    test(
      'U13: steps execute in the target project\'s working directory',
      () async {
        // The fake zfa script writes a relative marker in its CWD.
        final markerPath = p.join(fx.root.path, 'pipeline_ran_here.marker');
        final logPath = fx.fakeZfaLogPath;
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: logPath,
          sideEffectByArgv: {
            'build': ['pwd > pipeline_ran_here.marker'],
          },
        );

        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            GenerationStepSpec(args: ['build'], purpose: 'p1'),
          ],
        );
        await runner.runPlan(
          plan: plan,
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        // Resolve symlinks so the marker the subprocess writes via `pwd`
        // (canonical /private/var on macOS, where /var -> /private/var)
        // matches the fixture root regardless of platform.
        final expectedCwd = Directory(fx.root.path).resolveSymbolicLinksSync();
        expect(await File(markerPath).readAsString(), '$expectedCwd\n');
      },
    );
  });

  group('bug #826 — kill classification, telemetry, bounded subprocess', () {
    /// A fake zfa whose `make ...` invocation SIGKILLs itself — the exact
    /// exit -9 signature the OS OOM killer leaves behind (bug #826), made
    /// deterministic without real memory pressure.
    Future<String> writeSigkillZfa() async {
      final binDir = Directory(p.join(fx.root.path, 'fake_bin_kill'));
      await binDir.create(recursive: true);
      final scriptPath = p.join(binDir.path, 'zfa');
      await File(scriptPath).writeAsString('''
#!/usr/bin/env bash
LOG="${fx.fakeZfaLogPath}"
echo "\$*" >> "\$LOG"
case "\$*" in
  make|make\\ *)
    kill -9 \$\$
    ;;
  *)
    exit 0
    ;;
esac
''');
      await Process.run('chmod', ['+x', scriptPath]);
      return scriptPath;
    }

    /// A fake zfa whose `make ...` invocation outlives any short deadline.
    /// Blocks in the shell itself (`read -t` — no grandchild process), so
    /// the deadline kill closes the output pipes deterministically.
    Future<String> writeHangingZfa() async {
      final binDir = Directory(p.join(fx.root.path, 'fake_bin_hang'));
      await binDir.create(recursive: true);
      final scriptPath = p.join(binDir.path, 'zfa');
      await File(
        scriptPath,
      ).writeAsString('#!/usr/bin/env bash\nread -t 30 x\nexit 0\n');
      await Process.run('chmod', ['+x', scriptPath]);
      return scriptPath;
    }

    GenerationPlan makePlan() => GenerationPlan(
      behaviorId: 'A1',
      feature: fx.featureName,
      sourceCriterion: 'FR-006',
      steps: [
        GenerationStepSpec(
          args: ['make', 'a1', '--no-entity'],
          purpose: 'generate use-case/repository scaffolds for a1',
        ),
        GenerationStepSpec(args: ['build'], purpose: 'build generated code'),
      ],
    );

    test('K1: a SIGKILLed generation step is classified resource-limit '
        'with resource telemetry — never a bare failure', () async {
      final zfaBin = await writeSigkillZfa();
      const runner = PipelineRunner();
      final result = await runner.runPlan(
        plan: makePlan(),
        workingDirectory: fx.root.path,
        zfaBinOverride: zfaBin,
      );
      expect(result.completed, isFalse);
      expect(result.firstFailureIndex, 0);
      expect(result.steps, hasLength(1)); // plan stopped, build never ran
      final step = result.steps.single;
      // The OOM signature: the child died by SIGKILL (Dart encodes a
      // signal-killed child as a negative exit code; SIGKILL is -9).
      expect(step.exitCode, -9);
      expect(step.timedOut, isFalse);
      expect(step.killClass, GenerationKillClass.resourceLimit);
      expect(step.verdictLabel, 'resource-limit');
      final telemetry = step.telemetry;
      expect(telemetry, isNotNull);
      expect(telemetry!.rssBeforeKb, greaterThan(0));
      expect(telemetry.rssAfterKb, greaterThan(0));
      expect(telemetry.wallClockMs, greaterThanOrEqualTo(0));
      final json = step.verdictJson();
      expect(json['verdict'], 'resource-limit');
      expect(json['exitCode'], -9);
      expect(json['rssBeforeKb'], telemetry.rssBeforeKb);
      expect(json['rssAfterKb'], telemetry.rssAfterKb);
      expect(json['wallClockMs'], telemetry.wallClockMs);
    });

    test(
      'K2: a step killed at the per-step deadline is classified timeout',
      () async {
        final zfaBin = await writeHangingZfa();
        const runner = PipelineRunner();
        final result = await runner.runPlan(
          plan: makePlan(),
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
          timeout: const Duration(milliseconds: 700),
        );
        expect(result.completed, isFalse);
        final step = result.steps.single;
        expect(step.timedOut, isTrue);
        expect(step.killClass, GenerationKillClass.timeout);
        expect(step.verdictLabel, 'timeout');
        expect(step.telemetry, isNotNull);
        expect(
          step.telemetry!.wallClockMs,
          greaterThanOrEqualTo(600),
          reason: 'the deadline fired before the child finished',
        );
      },
    );

    test(
      'K3: ordinary steps stay unclassified but still carry telemetry',
      () async {
        final logPath = fx.fakeZfaLogPath;
        final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);
        const runner = PipelineRunner();
        final result = await runner.runPlan(
          plan: makePlan(),
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        expect(result.completed, isTrue);
        for (final step in result.steps) {
          expect(step.exitCode, 0);
          expect(step.killClass, GenerationKillClass.none);
          expect(step.verdictLabel, isNull);
          expect(step.telemetry, isNotNull);
          expect(step.telemetry!.rssBeforeKb, greaterThan(0));
        }
      },
    );

    test(
      'K4: an ordinary exit-1 failure keeps the honest unclassified stop',
      () async {
        final logPath = fx.fakeZfaLogPath;
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: logPath,
          exitByArgv: {'make': 1},
        );
        const runner = PipelineRunner();
        final result = await runner.runPlan(
          plan: makePlan(),
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        expect(result.completed, isFalse);
        final step = result.steps.first;
        expect(step.exitCode, 1);
        expect(step.killClass, GenerationKillClass.none);
        expect(step.verdictLabel, isNull);
      },
    );

    test(
      'K5: the bounded spawn runs the step under the configured '
      'address-space ceiling (Linux)',
      skip: Platform.isLinux
          ? false
          : 'ulimit -v is only kernel-enforced on Linux; the bound is '
                'best-effort on macOS and absent on Windows',
      () async {
        // The fake zfa reports its own address-space ceiling — the value
        // the wrapper's `ulimit -v` installed in the child.
        final binDir = Directory(p.join(fx.root.path, 'fake_bin_cap'));
        await binDir.create(recursive: true);
        final zfaBin = p.join(binDir.path, 'zfa');
        await File(zfaBin).writeAsString(
          '#!/usr/bin/env bash\n'
          'echo "cap=\$(ulimit -v)"\n'
          'exit 0\n',
        );
        await Process.run('chmod', ['+x', zfaBin]);
        const runner = PipelineRunner();
        final result = await runner.runPlan(
          plan: makePlan(),
          workingDirectory: fx.root.path,
          zfaBinOverride: zfaBin,
        );
        expect(result.completed, isTrue);
        expect(result.steps.first.output, contains('cap=2097152'));
      },
    );

    test(
      'K6: resolveStepMemoryLimitKb — env override, 0 disables, garbage',
      () {
        const defaultKb = 2 * 1024 * 1024;
        // Default: the 2 GiB ceiling on POSIX, no bound on Windows.
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {}, isWindows: false),
          defaultKb,
        );
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {}, isWindows: true),
          isNull,
        );
        // Explicit override wins.
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {
            'ZFA_TDD_STEP_MEMORY_KB': '1048576',
          }, isWindows: false),
          1048576,
        );
        // 0 opts out of the bound entirely.
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {
            'ZFA_TDD_STEP_MEMORY_KB': '0',
          }, isWindows: false),
          isNull,
        );
        // Garbage falls back to the default instead of guessing.
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {
            'ZFA_TDD_STEP_MEMORY_KB': 'unlimited',
          }, isWindows: false),
          defaultKb,
        );
        expect(
          PipelineRunner.resolveStepMemoryLimitKb(const {
            'ZFA_TDD_STEP_MEMORY_KB': '-5',
          }, isWindows: false),
          defaultKb,
        );
      },
    );
  });
}
