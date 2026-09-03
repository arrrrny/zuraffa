/// Spec 069-corpus-economics, T003 — sharding + concurrency + budget
/// telemetry in the corpus lane's JSON verdict (issue #916: per-PR
/// corpus lane ≤ 10 min via sharding).
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../helpers/corpus_fixture.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late CorpusFixture fx;

  setUp(() async {
    fx = await CorpusFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> drive({List<String> extra = const []}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'corpus',
      'run',
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeBin,
      ...extra,
    ]);
  }

  Future<Map<String, dynamic>> readVerdict() async =>
      jsonDecode(await File(fx.verdictPath).readAsString())
          as Map<String, dynamic>;

  group('T003.1 --shard <i>/<k> (deterministic lane scoping)', () {
    test(
      'drives ONLY this lane\u2019s features; the verdict is lane-scoped',
      () async {
        await fx.writeManifest([
          (name: 'f1', ready: true, reason: ''),
          (name: 'f2', ready: true, reason: ''),
          (name: 'f3', ready: true, reason: ''),
          (name: 'f4', ready: true, reason: ''),
        ]);
        await fx.writeFakeZfa();

        final out = await drive(extra: ['--shard', '1/2']);
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains('[corpus] shard 1/2: 2 of 4 feature(s)'),
          reason: out,
        );
        expect(out, contains('shard=1/2'), reason: out);

        // Round-robin lane 1 of 2: f1, f3 only.
        final calls = await fx.readCalls();
        expect(calls, contains('tdd run f1 --project ${fx.root.path}'));
        expect(calls, contains('tdd run f3 --project ${fx.root.path}'));
        expect(calls.where((c) => c.contains(' run ')).length, 2);
        expect(calls, isNot(contains('tdd run f2 --project ${fx.root.path}')));
        expect(calls, isNot(contains('tdd run f4 --project ${fx.root.path}')));

        // The verdict JSON records the shard + lane-scoped completeness.
        final verdict = await readVerdict();
        expect(verdict['result'], 'complete');
        expect(verdict['shard'], '1/2');
        expect((verdict['features'] as Map<String, dynamic>)['lane'], 2);
      },
    );

    test(
      'the complementary lane covers the rest (matrix union = corpus)',
      () async {
        await fx.writeManifest([
          (name: 'f1', ready: true, reason: ''),
          (name: 'f2', ready: true, reason: ''),
          (name: 'f3', ready: true, reason: ''),
          (name: 'f4', ready: true, reason: ''),
        ]);
        await fx.writeFakeZfa();

        await drive(extra: ['--shard', '1/2']);
        exitCode = 0;
        final out2 = await drive(extra: ['--shard', '2/2']);
        expect(exitCode, 0, reason: out2);

        // Lane 2 drove f2 and f4 (f1/f3 were lane 1's business — never
        // re-driven by lane 2).
        final calls = await fx.readCalls();
        expect(calls, contains('tdd run f2 --project ${fx.root.path}'));
        expect(calls, contains('tdd run f4 --project ${fx.root.path}'));
        expect(calls.where((c) => c.contains(' run ')).length, 4);

        final verdict = await readVerdict();
        expect(verdict['shard'], '2/2');
        expect(verdict['result'], 'complete');
      },
    );

    test('a malformed shard spec stops BEFORE anything is driven', () async {
      await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
      await fx.writeFakeZfa();

      final out = await drive(extra: ['--shard', 'banana']);
      expect(out, contains('invalid --shard'), reason: out);
      expect(out, contains('result=runner-error'), reason: out);
      expect(exitCode, 2, reason: out);
      expect(await fx.readCalls(), isEmpty);
    });

    test('an out-of-range lane index is refused', () async {
      await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
      await fx.writeFakeZfa();

      final out = await drive(extra: ['--shard', '5/4']);
      expect(out, contains('invalid --shard'), reason: out);
      expect(exitCode, 2, reason: out);
      expect(await fx.readCalls(), isEmpty);
    });
  });

  group('T003.2 budget telemetry in the JSON verdict', () {
    test(
      'the verdict carries wall-clock per step, suite seconds, mutants',
      () async {
        await fx.writeManifest([
          (name: 'f1', ready: true, reason: ''),
          (name: 'f2', ready: true, reason: ''),
        ]);
        await fx.writeFakeZfa();

        final out = await drive();
        expect(exitCode, 0, reason: out);

        final verdict = await readVerdict();
        expect(verdict['result'], 'complete');
        expect(verdict['shard'], isNull);

        final budget = verdict['budget'] as Map<String, dynamic>;
        final wall = budget['wall_clock_ms'] as Map<String, dynamic>;
        expect(wall['run'], greaterThan(0));
        expect(wall['verify'], greaterThan(0));
        expect(
          wall['total'] as num,
          greaterThanOrEqualTo((wall['run'] as num) + (wall['verify'] as num)),
        );
        // The default fake reports killed=1 per verify -> 2 mutants.
        expect(budget['mutant_count'], 2);
        expect(budget['suite_seconds'], isA<num>());

        // The machine line names the verdict path + the budget axes.
        expect(out, contains('verdict:'), reason: out);
        expect(out, contains('mutants=2'), reason: out);
      },
    );

    test(
      'a failing verify with mutation counters still counts mutants',
      () async {
        await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
        await fx.writeFakeZfa(
          outcomes: {
            'verify:f1': (
              exit: 1,
              stdout: [
                'mutation: gate=fail-survived killed=3 survived=2 '
                    'timed_out=1 mutation_was_run=true',
              ],
            ),
          },
        );

        final out = await drive();
        expect(exitCode, 1, reason: out);
        expect(out, contains('result=stopped'), reason: out);

        final verdict = await readVerdict();
        expect(verdict['result'], 'stopped');
        // killed 3 + survived 2 + timed_out 1 = 6 assessed mutants.
        expect((verdict['budget'] as Map<String, dynamic>)['mutant_count'], 6);
      },
    );
  });

  group('T003.3 --concurrency <n> (in-process feature lanes)', () {
    /// A fake zfa that sleeps 300ms per invocation so parallel lanes
    /// observably interleave (the argv log order proves it).
    Future<void> writeSleepingFake() async {
      final dir = Directory(p.dirname(fx.fakeBin));
      await dir.create(recursive: true);
      await File(fx.callsLog).writeAsString('');
      await File(fx.fakeBin).writeAsString('''
#!/usr/bin/env bash
ARGV="\$*"
echo "\$ARGV" >> "${fx.callsLog}"
sleep 0.3
if [[ "\$ARGV" == *" run "* ]]; then
  FEATURE="\${ARGV#* run }"
  FEATURE="\${FEATURE%% *}"
  echo "run: feature=\$FEATURE result=complete pending=0 red=0 green=1 done=1"
  exit 0
fi
echo "mutation: gate=pass killed=1 survived=0 timed_out=0 mutation_was_run=true"
exit 0
''');
      await Process.run('chmod', ['+x', fx.fakeBin]);
    }

    test(
      'two lanes interleave: the second run starts before the first verify',
      () async {
        await fx.writeManifest([
          (name: 'f1', ready: true, reason: ''),
          (name: 'f2', ready: true, reason: ''),
        ]);
        await writeSleepingFake();

        final out = await drive(extra: ['--concurrency', '2']);
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains('[corpus] concurrency: 2 feature lane(s)'),
          reason: out,
        );

        final calls = await fx.readCalls();
        // With 300ms per step: sequential would be run f1, verify f1,
        // run f2, verify f2. Two lanes interleave: run f2 logs while
        // f1's run is still sleeping — BEFORE verify f1.
        final runF1 = calls.indexWhere((c) => c.contains(' run f1 '));
        final runF2 = calls.indexWhere((c) => c.contains(' run f2 '));
        final verifyF1 = calls.indexWhere(
          (c) => c.contains(' verify ') && c.contains('f1'),
        );
        expect(runF1, greaterThanOrEqualTo(0));
        expect(runF2, greaterThan(runF1), reason: calls.toString());
        expect(runF2, lessThan(verifyF1), reason: calls.toString());
        expect(verifyF1, greaterThan(runF1));

        // Both features reached done.
        final progress = await fx.readProgress();
        final features = progress!['features'] as Map<String, dynamic>;
        expect((features['f1'] as Map)['state'], 'done');
        expect((features['f2'] as Map)['state'], 'done');
      },
    );

    test(
      'STOP-ON-ROADBLOCK holds: a failed lane stops NEW lanes, in-flight drains honestly',
      () async {
        await fx.writeManifest([
          (name: 'f1', ready: true, reason: ''),
          (name: 'f2', ready: true, reason: ''),
          (name: 'f3', ready: true, reason: ''),
        ]);
        // f1's run fails (roadblock at the FIRST lane); f2 is in flight
        // concurrently and completes; f3 must never start.
        await fx.writeFakeZfa(
          outcomes: {
            'run:f1': (
              exit: 1,
              stdout: ['run: feature=f1 result=stopped stopped_at=B-001:make'],
            ),
          },
        );

        final out = await drive(extra: ['--concurrency', '2']);
        expect(exitCode, 1, reason: out);
        expect(out, contains('result=stopped'), reason: out);
        expect(out, contains('stopped_at=f1'), reason: out);

        final calls = await fx.readCalls();
        expect(
          calls.where((c) => c.contains(' run f3 ')),
          isEmpty,
          reason: 'f3 must never start after the roadblock',
        );
        // f2 was in flight and drained to completion honestly.
        final progress = await fx.readProgress();
        final features = progress!['features'] as Map<String, dynamic>;
        expect((features['f1'] as Map)['state'], 'stopped');
        expect((features['f2'] as Map)['state'], 'done');
      },
    );

    test('invalid concurrency is a usage-class refusal', () async {
      await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
      await fx.writeFakeZfa();
      final out = await drive(extra: ['--concurrency', 'zero']);
      expect(out, contains('invalid --concurrency'), reason: out);
      expect(exitCode, 2, reason: out);
      expect(await fx.readCalls(), isEmpty);
    });
  });
}
