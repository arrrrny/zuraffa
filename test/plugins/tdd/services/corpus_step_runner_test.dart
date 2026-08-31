// Tests for CorpusStepRunner (spec 051-corpus-harness, U15-U18): the
// sub-process spawner for `zfa tdd run` / `zfa tdd verify`, driven with an
// injected spawner (no real processes — the slow tier exercises real
// spawns via the fixture's fake zfa binary).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_step_runner.dart';

void main() {
  const projectRoot = '/tmp/app';

  group('U15 — tdd run spawn + parse', () {
    test('spawns the agreed argv and parses result + stopped_at', () async {
      var spawned = const <String>[];
      final runner = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async {
          spawned = command;
          return ProcessResult(0, 1, '''
zfa tdd run: step failed — behavior=B-002 step=make outcome=unexpressible
run: feature=f2-gap result=stopped pending=0 red=1 green=0 done=0 stopped_at=B-002:make
''', '');
        },
      );
      final result = await runner.runFeature(
        feature: 'f2-gap',
        projectRoot: projectRoot,
      );
      expect(spawned, [
        '/fake/zfa',
        'tdd',
        'run',
        'f2-gap',
        '--project',
        projectRoot,
      ], reason: 'a non-.dart entrypoint executes directly with the run argv');
      expect(result.step, CorpusStep.run);
      expect(result.exitCode, 1);
      expect(result.outcome, 'stopped');
      expect(result.stoppedAt, 'B-002:make');
      expect(result.success, isFalse);
    });

    test('success is exit 0 AND result=complete', () async {
      final runner = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async => ProcessResult(
          0,
          0,
          'run: feature=f1-good result=complete pending=0 red=0 green=1 done=1',
          '',
        ),
      );
      final ok = await runner.runFeature(
        feature: 'f1-good',
        projectRoot: projectRoot,
      );
      expect(ok.success, isTrue);
      expect(ok.outcome, 'complete');
      expect(ok.stoppedAt, isNull);

      // Exit 0 with a non-complete result is NOT success.
      final drift = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async => ProcessResult(
          0,
          0,
          'run: feature=f1-good result=stopped pending=1',
          '',
        ),
      );
      final stopped = await drift.runFeature(
        feature: 'f1-good',
        projectRoot: projectRoot,
      );
      expect(stopped.success, isFalse);
      expect(stopped.outcome, 'stopped');
    });

    test('a .dart entrypoint is executed through dart', () async {
      var spawned = const <String>[];
      final runner = CorpusStepRunner(
        zfaBin: '/pkg/bin/zfa.dart',
        spawner: (command, cwd) async {
          spawned = command;
          return ProcessResult(
            0,
            0,
            'run: feature=f result=complete pending=0',
            '',
          );
        },
      );
      await runner.runFeature(feature: 'f', projectRoot: projectRoot);
      expect(spawned.first, 'dart');
      expect(spawned[1], '/pkg/bin/zfa.dart');
    });
  });

  group('U16 — tdd verify spawn + parse', () {
    test('spawns the agreed argv and parses the gate label', () async {
      var spawned = const <String>[];
      final runner = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async {
          spawned = command;
          return ProcessResult(
            0,
            1,
            'mutation: gate=fail_survived killed=3 survived=2 timed_out=0 '
                'mutation_was_run=true',
            'audit failed',
          );
        },
      );
      final result = await runner.verifyFeature(
        feature: 'f2-gap',
        projectRoot: projectRoot,
      );
      expect(spawned, [
        '/fake/zfa',
        'tdd',
        'verify',
        '--feature',
        'f2-gap',
        '--project',
        projectRoot,
      ]);
      expect(result.step, CorpusStep.verify);
      expect(result.outcome, 'fail_survived');
      // The label is surfaced even with a non-zero exit (never absorbed).
      expect(result.success, isFalse);
    });

    test('success is exit 0 AND gate=pass', () async {
      final passing = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async => ProcessResult(
          0,
          0,
          'mutation: gate=pass killed=4 survived=0 timed_out=0 '
              'mutation_was_run=true',
          '',
        ),
      );
      final ok = await passing.verifyFeature(
        feature: 'f',
        projectRoot: projectRoot,
      );
      expect(ok.success, isTrue);
      expect(ok.outcome, 'pass');

      // gate=pass but exit 1: NOT success (contract disagreement).
      final lying = CorpusStepRunner(
        zfaBin: '/fake/zfa',
        spawner: (command, cwd) async => ProcessResult(
          0,
          1,
          'mutation: gate=pass killed=4 survived=0 timed_out=0',
          '',
        ),
      );
      final mismatch = await lying.verifyFeature(
        feature: 'f',
        projectRoot: projectRoot,
      );
      expect(mismatch.success, isFalse);
    });
  });

  group('U17 — missing summary line', () {
    test('exit 0 without the machine line is a runner-error misfire', () async {
      for (final step in [CorpusStep.run, CorpusStep.verify]) {
        final runner = CorpusStepRunner(
          zfaBin: '/fake/zfa',
          spawner: (command, cwd) async =>
              ProcessResult(0, 0, 'all done, trust me', ''),
        );
        final result = switch (step) {
          CorpusStep.run => await runner.runFeature(
            feature: 'f',
            projectRoot: projectRoot,
          ),
          CorpusStep.verify => await runner.verifyFeature(
            feature: 'f',
            projectRoot: projectRoot,
          ),
        };
        expect(result.success, isFalse, reason: '$step');
        expect(result.outcome, 'runner-error', reason: '$step');
      }
    });
  });

  group('U18 — spawn failure', () {
    test('a ProcessException yields runner-error, never a crash', () async {
      final runner = CorpusStepRunner(
        zfaBin: '/nonexistent/zfa',
        spawner: (command, cwd) async {
          throw ProcessException(command.first, command.sublist(1));
        },
      );
      final result = await runner.runFeature(
        feature: 'f',
        projectRoot: projectRoot,
      );
      expect(result.success, isFalse);
      expect(result.outcome, 'runner-error');
      expect(result.exitCode, -1);
      expect(result.output, contains('spawn failed'));
    });

    test(
      'entrypoint resolution failure yields runner-error before spawn',
      () async {
        var spawned = false;
        final runner = CorpusStepRunner(
          entryResolver: () async => throw StateError('cannot resolve'),
          spawner: (command, cwd) async {
            spawned = true;
            return ProcessResult(0, 0, '', '');
          },
        );
        final result = await runner.runFeature(
          feature: 'f',
          projectRoot: projectRoot,
        );
        expect(spawned, isFalse);
        expect(result.success, isFalse);
        expect(result.outcome, 'runner-error');
        expect(result.output, contains('entrypoint resolution failed'));
      },
    );
  });
}
