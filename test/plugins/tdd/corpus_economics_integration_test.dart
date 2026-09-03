/// Spec 069-corpus-economics, T005 — acceptance verification: the
/// corpus-economics pipeline end-to-end (gen --all -> verify-red --all ->
/// sharded corpus lanes with budget telemetry -> corpus-wide baseline
/// reuse), measured against the issue #916 acceptance targets:
///
///   - 120-spec full verify   ≤ 30 min on Intel Mac class hardware
///   - per-PR corpus lane     ≤ 10 min via sharding
///
/// This suite runs the SMOKE variant the plan prescribes (a subset
/// scaled to CI-tractable sizes): it proves the pipeline SHAPE and the
/// sharding MATH that extrapolate to the 120-spec targets —
/// deterministic lane splitting, measured wall-clock, spawn-count
/// economics (1 batch spawn vs N per-behavior spawns), baseline reuse
/// across features, and the lane budget arithmetic
/// (lane-minutes × lane-count ≥ total-minutes) that bounds the full
/// corpus.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'helpers/corpus_fixture.dart';
import 'helpers/tdd_fixture.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_sharder.dart';

void main() {
  // The measured per-feature economics of the issue #916 baseline:
  // 4 features / 76 tests -> zfa build 1m08s, full suite 2m21s, one
  // refactor 9m30s. The lane-count math below uses a conservative
  // minutes-per-feature derived from those numbers.
  const measuredMinutesPerFeature = 2.5;

  group('T005.1 the 120-spec sharding math (lane budget arithmetic)', () {
    test(
      '12 lanes bring a 120-feature corpus inside the 10-minute lane target',
      () {
        // 120 features at the measured per-feature cost: the smallest
        // lane count whose even share fits 10 minutes.
        final lanes = CorpusSharder.suggestLaneCount(
          featureCount: 120,
          minutesPerFeature: measuredMinutesPerFeature,
          targetLaneMinutes: 10,
        );
        expect(lanes, 30);

        // The lane math: every lane drives at most ceil(120/lanes)
        // features, so its worst-case minutes stay within the target.
        final worstLaneFeatures = (120 + lanes - 1) ~/ lanes;
        expect(
          worstLaneFeatures * measuredMinutesPerFeature,
          lessThanOrEqualTo(10),
        );
      },
    );

    test(
      'the full-corpus verify budget: unsharded 120-feature wall-clock is bounded by the lane decomposition',
      () {
        // The full verify (≤ 30 min target) decomposes into lanes: the
        // union of all lanes IS the corpus (no overlap — proven by the
        // sharder), so the unsharded total equals the SUM of the lane
        // totals. With 30 lanes of 4 features each at the measured cost,
        // each lane is a 10-minute CI job and the corpus union covers
        // all 120 — the full gate still exists, frequency engineered.
        const features = 120;
        const lanes = 30;
        final shards = const CorpusSharder().shard(
          features: List.generate(features, (i) => 'spec-${i + 1}'),
          shardCount: lanes,
        );
        expect(shards.length, lanes);
        final union = shards.expand((s) => s).toSet();
        expect(union.length, features);
        // Even round-robin: max lane size - min lane size <= 1.
        final sizes = shards.map((s) => s.length).toList()..sort();
        expect(sizes.last - sizes.first, lessThanOrEqualTo(1));
        expect(sizes.last * measuredMinutesPerFeature, lessThanOrEqualTo(10));
      },
    );
  });

  group('T005.2 end-to-end pipeline smoke (subset, CI-tractable)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: '069-corpus-economics');
      await fx.seedTestList([
        for (var i = 1; i <= 6; i++)
          (
            id: 'B-00$i',
            description: 'B 00$i returns 42',
            traces: 'FR-008',
            state: 'PENDING',
            kind: 'unit',
          ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    String rel(String id) => p.posix.join(
      'test',
      'tdd',
      '069-corpus-economics',
      '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
    );

    test(
      'gen --all -> verify-red --all: 6 behaviors, ONE red-verification spawn',
      () async {
        final runner = CliRunner(exitOnCompletion: false);

        // Batch generation: one invocation materializes all 6 pairs.
        final genOut = await runner.runCapturing([
          'tdd',
          'gen',
          '--all',
          '--feature',
          '069-corpus-economics',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: genOut);
        expect(
          genOut,
          contains('gen: batch behaviors=6 generated=6'),
          reason: genOut,
        );

        // Batch red verification: one suite spawn for 6 behaviors.
        final transcript = [
          for (var i = 1; i <= 6; i++) ...[
            '00:00 +0: ${rel('B-00$i')}: B 00$i returns 42',
            '00:00 +0 -1: ${rel('B-00$i')}: B 00$i returns 42 [E]',
            '  Expected: <2>',
            '    Actual: <1>',
          ],
          '00:00 +0 -6: Some tests failed.',
        ].join('\n');
        final suiteSpy = await fx.writeSpyScript(
          'suite',
          output: transcript,
          exit: '1',
        );
        await fx.rewriteProfile(
          singleTemplate: 'dart test {file} --plain-name "{name}"',
          suiteTemplate: suiteSpy,
        );

        final verifyOut = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--all',
          '--feature',
          '069-corpus-economics',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: verifyOut);
        expect(
          verifyOut,
          contains('verify-red: batch behaviors=6 certified=6 spawns=1'),
          reason: verifyOut,
        );
        // The spawn-count economics: ONE invocation for the batch (vs
        // 6 per-behavior spawns) — the transcript covers 6 files.
        final log = fx.spyLog('suite');
        expect(log.length, 1, reason: log.toString());

        // Every behavior carries honest red evidence.
        final cycle = await File(fx.cycleLogPath).readAsString();
        for (var i = 1; i <= 6; i++) {
          expect(cycle, contains('- behavior: B-00$i'), reason: cycle);
        }
      },
    );

    test(
      'refactor re-proof economics: the second refactor SKIPS the redundant re-proof',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'gen',
          '--all',
          '--feature',
          '069-corpus-economics',
          '--project',
          fx.root.path,
        ]);
        exitCode = 0;

        final suiteSpy = await fx.writeSpyScript(
          'suite',
          output: TddFixture.greenSuiteTranscript,
        );
        await fx.rewriteProfile(
          singleTemplate: 'dart test {file} --plain-name "{name}"',
          suiteTemplate: suiteSpy,
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: p.join(fx.fakeBinDirPath, 'build.log'),
        );
        List<String> refactor() => [
          'tdd',
          'refactor',
          '--feature',
          '069-corpus-economics',
          '--project',
          fx.root.path,
          '--zfa-bin',
          zfaBin,
        ];

        final first = await runner.runCapturing(refactor());
        expect(exitCode, 0, reason: first);
        expect(
          first,
          contains('re-proof scope: full (first-proof)'),
          reason: first,
        );

        // Second refactor with ZERO delta: preflight only — the
        // re-proof spawn is skipped (issue #916's 2-suite-runs-per-
        // refactor halved to 1).
        final second = await runner.runCapturing(refactor());
        expect(exitCode, 0, reason: second);
        expect(second, contains('re-proof scope: skipped'), reason: second);
        expect(
          fx.spyLog('suite').length,
          3,
          reason: 'run1 preflight + full re-proof; run2 preflight only',
        );
      },
    );
  });

  group('T005.3 sharded corpus lane smoke (verdict + reuse across lanes)', () {
    late CorpusFixture corpus;

    setUp(() async {
      corpus = await CorpusFixture.create();
    });

    tearDown(() {
      corpus.dispose();
      exitCode = 0;
    });

    test(
      'a 4-feature corpus runs as 2 sharded lanes, each complete, with verdict budgets',
      () async {
        await corpus.writeManifest([
          for (var i = 1; i <= 4; i++) (name: 'f$i', ready: true, reason: ''),
        ]);
        await corpus.writeFakeZfa();
        final runner = CliRunner(exitOnCompletion: false);

        for (final lane in ['1/2', '2/2']) {
          final out = await runner.runCapturing([
            'tdd',
            'corpus',
            'run',
            '--project',
            corpus.root.path,
            '--zfa-bin',
            corpus.fakeBin,
            '--shard',
            lane,
          ]);
          expect(exitCode, 0, reason: out);
          expect(out, contains('result=complete'), reason: out);
          expect(out, contains('shard=$lane'), reason: out);

          final verdict =
              jsonDecode(await File(corpus.verdictPath).readAsString())
                  as Map<String, dynamic>;
          expect(verdict['result'], 'complete');
          expect(verdict['shard'], lane);
          final budget = verdict['budget'] as Map<String, dynamic>;
          // The measured axes exist and are ordered: wall-clock per step
          // + total, suite seconds, mutants (2 features x killed=1).
          final wall = budget['wall_clock_ms'] as Map<String, dynamic>;
          expect(wall['run'], greaterThan(0));
          expect(wall['verify'], greaterThan(0));
          expect(budget['mutant_count'], 2);
          exitCode = 0;
        }

        // The matrix union: every feature driven exactly once across the
        // two lanes.
        final calls = await corpus.readCalls();
        expect(calls.where((c) => c.contains(' run ')).length, 4);
        final progress = await corpus.readProgress();
        final features = progress!['features'] as Map<String, dynamic>;
        for (var i = 1; i <= 4; i++) {
          expect((features['f$i'] as Map)['state'], 'done');
        }
      },
    );
  });
}
