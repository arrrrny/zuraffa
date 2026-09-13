// Issue #1590 — progress liveness for `zfa tdd run` and the make pipeline.
//
// The driver printed nothing while a step ran (a single make ran 273.7s in
// silence); the pipeline runner spawned each sub-step with no banner; make's
// plan line carried only a count. This suite pins the output contracts at
// the unit tier: the banner/name mappings, the plan line, the driver's
// step-start + heartbeat line builders, the `--heartbeat` parse contract,
// and the byte-faithful stdout tee in `runTimed`. The driven (end-to-end)
// contracts live in the slow tier: `run_command_test.dart`, group
// `#1590 progress liveness`.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_driver_core.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/pipeline_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

import 'helpers/tdd_fixture.dart';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a list of lines, in print order.
Future<List<String>> capturePrintLines(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output;
}

GenerationStepSpec _spec(List<String> args) =>
    GenerationStepSpec(args: args, purpose: 'p');

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
  });

  group('pipeline banners (U-1590-1, SC-2)', () {
    test('bannerFor/nameFor mapping is exact', () {
      // tdd-prefixed → the subcommand verb.
      final func = _spec(['tdd', 'func', 'A1', '--feature', 'f']);
      expect(PipelineRunner.nameFor(func), 'func');
      expect(PipelineRunner.bannerFor(func), '→ func');
      final wire = _spec(['tdd', 'wire', 'A1', '--entity', 'User']);
      expect(PipelineRunner.bannerFor(wire), '→ wire');
      final compose = _spec(['tdd', 'compose', 'A1', '--feature', 'f']);
      expect(PipelineRunner.bannerFor(compose), '→ compose');

      // build → the hint the issue asks for.
      final build = _spec(['build']);
      expect(PipelineRunner.nameFor(build), 'build');
      expect(
        PipelineRunner.bannerFor(build),
        '→ build (build_runner + analyze; minutes on first run)',
      );

      // entity create → the entity name.
      expect(
        PipelineRunner.bannerFor(
          _spec(['entity', 'create', 'User', '--fields=email']),
        ),
        '→ entity create User',
      );

      // make → the target name.
      expect(
        PipelineRunner.bannerFor(_spec(['make', 'User', '--no-entity'])),
        '→ make User',
      );

      // mock create → the mock verb.
      expect(
        PipelineRunner.bannerFor(
          _spec(['mock', 'create', '--name', 'X', '--certify']),
        ),
        '→ mock create',
      );

      // Unknown → the first two args.
      expect(
        PipelineRunner.bannerFor(_spec(['weird', 'x', 'y', 'z'])),
        '→ weird x',
      );
      expect(PipelineRunner.bannerFor(_spec(['solo'])), '→ solo');
    });

    test(
      'runPlan prints exactly one banner per spawned step, in plan order',
      () async {
        final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            _spec(['tdd', 'func', 'B-001', '--feature', fx.featureName]),
            _spec(['build']),
          ],
        );

        final lines = await capturePrintLines(
          () => runner.runPlan(
            plan: plan,
            workingDirectory: fx.root.path,
            zfaBinOverride: zfaBin,
          ),
        );

        expect(lines, [
          '→ func',
          '→ build (build_runner + analyze; minutes on first run)',
        ], reason: 'banners precede each spawn, plan order');
      },
    );

    test(
      'misfire-stop: a failed first step never announces the second',
      () async {
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          exitByArgv: {'func': 1},
        );
        const runner = PipelineRunner();
        final plan = GenerationPlan(
          behaviorId: 'B-001',
          feature: fx.featureName,
          sourceCriterion: 'FR-006',
          steps: [
            _spec(['tdd', 'func', 'B-001', '--feature', fx.featureName]),
            _spec(['build']),
          ],
        );

        final lines = await capturePrintLines(
          () => runner.runPlan(
            plan: plan,
            workingDirectory: fx.root.path,
            zfaBinOverride: zfaBin,
          ),
        );

        expect(lines, [
          '→ func',
        ], reason: 'the build step never spawned, never announced');
      },
    );
  });

  group('make plan line names the steps (U-1590-2, SC-6)', () {
    test('expressible plan', () {
      final line = PipelineRunner.planSummaryLine([
        _spec(['tdd', 'func', 'A1', '--feature', 'f']),
        _spec(['build']),
      ]);
      expect(line, '   plan: 2 step(s): func, build');
    });

    test('composition fallback plan', () {
      final line = PipelineRunner.planSummaryLine([
        _spec(['tdd', 'compose', 'A1', '--feature', 'f']),
        _spec(['build']),
      ], compositionFallback: true);
      expect(line, '   plan: composition fallback — 2 step(s): compose, build');
    });
  });

  group('driver step-start line (U-1590-3, SC-1/SC-5)', () {
    test('static per-step hints', () {
      expect(
        RunDriverCore.stepStartLine('A1', 'gen'),
        '[run] A1 gen — scaffold test + stub',
      );
      expect(
        RunDriverCore.stepStartLine('A1', 'verify-red'),
        '[run] A1 verify-red — run target test (expect red)',
      );
      expect(
        RunDriverCore.stepStartLine('A1', 'make'),
        '[run] A1 make — generation pipeline (sub-steps announced as they '
        'start)',
      );
      expect(
        RunDriverCore.stepStartLine('A1', 'refactor'),
        '[run] A1 refactor — format + analyze + re-proof',
      );
    });

    test('resume suffix only for a foreign in-flight marker', () {
      expect(
        RunDriverCore.stepStartLine(
          'B-002',
          'gen',
          resumingInFlight: true,
          ownerPid: 4242,
        ),
        '[run] B-002 gen — scaffold test + stub (resuming in-flight step '
        'from run-state.json, owner pid 4242)',
      );
      // Not resuming → no suffix even with a pid around.
      expect(
        RunDriverCore.stepStartLine('A1', 'make', ownerPid: 4242),
        isNot(contains('resuming')),
      );
    });
  });

  group('heartbeat line + --heartbeat parse (U-1590-4, SC-4)', () {
    test('heartbeatLine formats elapsed via formatTddTimeout', () {
      expect(
        RunDriverCore.heartbeatLine('A1', 'make', const Duration(seconds: 30)),
        '[run] A1 make … 30s elapsed',
      );
      expect(
        RunDriverCore.heartbeatLine(
          'B-001',
          'refactor',
          const Duration(minutes: 2, seconds: 5),
        ),
        '[run] B-001 refactor … 2m05s elapsed',
      );
    });

    test('parseTddHeartbeatSeconds contract', () {
      expect(parseTddHeartbeatSeconds(null), isNull); // caller default (30s)
      expect(parseTddHeartbeatSeconds(''), isNull);
      expect(parseTddHeartbeatSeconds('0'), Duration.zero); // off
      expect(
        parseTddHeartbeatSeconds('0.05'),
        const Duration(milliseconds: 50),
      );
      expect(parseTddHeartbeatSeconds('30'), const Duration(seconds: 30));
      expect(
        () => parseTddHeartbeatSeconds('abc'),
        throwsA(isA<TddTimeoutFormatException>()),
      );
      expect(
        () => parseTddHeartbeatSeconds('-1'),
        throwsA(isA<TddTimeoutFormatException>()),
      );
    });
  });

  group('runTimed stdout tee (U-1590-5, FR-004)', () {
    test(
      'fires per complete line in order AND keeps stdout byte-faithful',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa_1590_tee');
        addTearDown(() => dir.delete(recursive: true));
        final script = p.join(dir.path, 'printer.sh');
        await File(script).writeAsString(
          '#!/usr/bin/env bash\necho "→ live-banner"\necho "plain line"\n',
        );
        await Process.run('chmod', ['+x', script]);

        final lines = <String>[];
        final result = await runTimed(
          script,
          const [],
          timeout: const Duration(seconds: 30),
          onStdoutLine: lines.add,
        );

        expect(lines, ['→ live-banner', 'plain line']);
        // Byte-faithful: identical to the pre-#1590 join() capture.
        expect(result.stdout, '→ live-banner\nplain line\n');
        expect(result.exitCode, 0);
      },
    );

    test('no callback → the pre-#1590 capture path is untouched', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_1590_tee');
      addTearDown(() => dir.delete(recursive: true));
      final script = p.join(dir.path, 'printer.sh');
      await File(
        script,
      ).writeAsString('#!/usr/bin/env bash\necho one\necho two\n');
      await Process.run('chmod', ['+x', script]);

      final result = await runTimed(
        script,
        const [],
        timeout: const Duration(seconds: 30),
      );

      expect(result.stdout, 'one\ntwo\n');
    });

    test('stderr is captured even when stdout has the tee callback', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_1590_tee');
      addTearDown(() => dir.delete(recursive: true));
      final script = p.join(dir.path, 'printer.sh');
      await File(script).writeAsString(
        '#!/usr/bin/env bash\necho out-line\necho err-line 1>&2\n',
      );
      await Process.run('chmod', ['+x', script]);

      final lines = <String>[];
      final result = await runTimed(
        script,
        const [],
        timeout: const Duration(seconds: 30),
        onStdoutLine: lines.add,
      );

      expect(lines, ['out-line']);
      expect(result.stderr, 'err-line\n');
      expect(result.stdout, 'out-line\n');
    });
  });
}
