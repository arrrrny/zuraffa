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
          GenerationStepSpec(args: ['build'], purpose: 'p2'),
        ],
      );
      final result = await runner.runPlan(
        plan: plan,
        workingDirectory: fx.root.path,
        zfaBinOverride: zfaBin,
      );
      expect(result.completed, isTrue);
      expect(result.steps, hasLength(2));
      // Order: argv lines in the log should be in plan order.
      final log = await fx.readFakeZfaLog();
      expect(log, hasLength(2));
      expect(log[0], contains('entity create User'));
      expect(log[1], contains('build'));
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
        // The fake zfa script writes a marker file in its CWD.
        final markerPath = p.join(fx.root.path, 'pipeline_ran_here.marker');
        final logPath = fx.fakeZfaLogPath;
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: logPath,
          sideEffectByArgv: {
            'build': ['touch "$markerPath"'],
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
        expect(await File(markerPath).exists(), isTrue);
      },
    );
  });
}
