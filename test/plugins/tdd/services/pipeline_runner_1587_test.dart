// Tests for the `PipelineRunner` build-skip scheduling seam (issue
// #1587): `runPlan(skipUnchangedBuild: true)` evaluates the changed-file
// set before an exactly-`['build']` step and skips the subprocess when
// no builder-consumable input changed, capturing a synthetic step for
// the audit. The flag defaults to OFF — callers that do not opt in keep
// spawning the build step unchanged (FR-008).
library;

import 'dart:io';

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

  GenerationPlan planOf(String id) => GenerationPlan(
    behaviorId: id,
    feature: fx.featureName,
    sourceCriterion: 'FR-006',
    steps: [
      GenerationStepSpec(args: ['tdd', 'func', id], purpose: 'subject edit'),
      GenerationStepSpec(args: ['build'], purpose: 'build'),
    ],
  );

  test('U3 (FR-002): no builder-consumable change → build step skipped '
      'with a synthetic captured step, subprocess never spawned', () async {
    final logPath = fx.fakeZfaLogPath;
    final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);

    const runner = PipelineRunner();
    final result = await runner.runPlan(
      plan: planOf('B-1587-1'),
      workingDirectory: fx.root.path,
      zfaBinOverride: zfaBin,
      skipUnchangedBuild: true,
    );

    expect(result.completed, isTrue);
    expect(result.steps, hasLength(2));
    final build = result.steps.last;
    expect(build.exitCode, 0);
    expect(build.buildSkipped, isTrue);
    expect(build.output, contains('issue #1587'));
    // The audit stays honest: only the func step was actually spawned.
    final log = await fx.readFakeZfaLog();
    expect(log, hasLength(1));
    expect(log.single, contains('tdd func B-1587-1'));
  });

  test('U3 (FR-001): an annotated dart write → the build step RUNS',
      () async {
    final logPath = fx.fakeZfaLogPath;
    final subjectPath = fx.subjectPathOf('B-1587-2');
    final subject = File(subjectPath);
    await subject.parent.create(recursive: true);
    await subject.writeAsString('// plain probe\nint b_value() => 0;\n');
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: logPath,
      sideEffectByArgv: {
        'tdd func': [
          "sed -i '1s|.*|// @Zorphy annotated probe — builder-consumable|' "
              '"$subjectPath"',
        ],
      },
    );

    const runner = PipelineRunner();
    final result = await runner.runPlan(
      plan: planOf('B-1587-2'),
      workingDirectory: fx.root.path,
      zfaBinOverride: zfaBin,
      skipUnchangedBuild: true,
    );

    expect(result.completed, isTrue);
    expect(result.steps, hasLength(2));
    expect(result.steps.last.buildSkipped, isFalse);
    final log = await fx.readFakeZfaLog();
    expect(log.where((l) => l.contains('build')), isNotEmpty);
  });

  test('U8 (FR-008): the flag defaults to OFF — build spawns unchanged',
      () async {
    final logPath = fx.fakeZfaLogPath;
    final zfaBin = await fx.writeFakeZfaBin(logPath: logPath);

    const runner = PipelineRunner();
    final result = await runner.runPlan(
      plan: planOf('B-1587-3'),
      workingDirectory: fx.root.path,
      zfaBinOverride: zfaBin,
    );

    expect(result.completed, isTrue);
    expect(result.steps, hasLength(2));
    expect(result.steps.last.buildSkipped, isFalse);
    final log = await fx.readFakeZfaLog();
    expect(log, hasLength(2));
    expect(log.last, contains('build'));
  });
}
