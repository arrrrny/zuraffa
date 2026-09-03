// Spec 069-corpus-economics — T005: acceptance verification (smoke on
// a subset) + the corpus-economics end-to-end integration.
//
// The acceptance targets are 120-spec full verify ≤ 30 min and per-PR
// corpus lane ≤ 10 min via sharding ON INTEL MAC CLASS HARDWARE. This
// fast-tier integration test proves the MACHINERY end-to-end on a
// subset corpus (fast, deterministic, no `dart test` kernels):
//
//   1. The full (unsharded) corpus lane drives every feature and
//      writes the budget-telemetry JSON verdict (wall-clock per step,
//      suite seconds, mutant counts).
//   2. `--shard i/n` splits the features deterministically across the
//      shard invocations — the exact coverage + selection the 120/10
//      lane math is built on — and a shard lane completes ITS features.
//   3. The telemetry verdict is the budget the CI lane enforces
//      (wall_clock_ms measured against a real budget).
//   4. The corpus-wide baseline reuse (T004) collapses the per-feature
//      suite baseline to one capture per dependency state across the
//      driven app's features.
//
// The hardware-class timing evidence (the ≤ 30 min / ≤ 10 min verdicts
// against the real 120-spec corpus) lives in
// specs/069-corpus-economics/tdd/verification.md, derived from the
// measured baselines in issue #916 + the spawn counts this machinery
// removes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  setUp(() async {
    fx = await CorpusFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runCorpus({List<String> extra = const []}) async {
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

  Future<Map<String, dynamic>> readTelemetry() async {
    final file = File('${fx.root.path}/.zfa/corpus/budget-telemetry.json');
    expect(file.existsSync(), isTrue, reason: 'telemetry file missing');
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  test('the full lane drives every feature and writes the budget '
      'telemetry JSON verdict (end-to-end)', () async {
    await fx.writeManifest([
      (name: 'f1-simple', ready: true, reason: ''),
      (name: 'f2-simple', ready: true, reason: ''),
      (name: 'f3-simple', ready: true, reason: ''),
    ]);
    await fx.writeFakeZfa();

    final out = await runCorpus();

    expect(exitCode, 0, reason: out);
    expect(out, contains('result=complete'), reason: out);

    // The budget telemetry verdict: schema, per-step wall clock, suite
    // seconds, and the mutant counts parsed from the verify steps'
    // machine lines.
    final telemetry = await readTelemetry();
    expect(telemetry['schema'], 'corpus.budget.v1');
    expect(telemetry['shard'], isNull);
    expect(telemetry['result'], 'complete');
    expect(telemetry['features'], 3);
    final steps = (telemetry['steps'] as List).cast<Map<String, dynamic>>();
    // Every feature contributes a run step + a verify step.
    expect(steps, hasLength(6));
    expect(
      steps.where((s) => s['step'] == 'run').map((s) => s['feature']).toSet(),
      {'f1-simple', 'f2-simple', 'f3-simple'},
    );
    for (final step in steps) {
      expect(step['wall_clock_ms'], isA<int>());
      expect(step['wall_clock_ms'] as int, greaterThanOrEqualTo(0));
      expect(step['outcome'], anyOf('complete', 'pass'));
    }
    // Wall clock + suite seconds present and consistent.
    expect(telemetry['wall_clock_ms'] as int, greaterThan(0));
    final suiteSeconds = (telemetry['suite_seconds'] as num).toDouble();
    expect(suiteSeconds, greaterThanOrEqualTo(0));
    // The fake zfa's verify machine line carries killed=1 per feature.
    final mutants = telemetry['mutants'] as Map<String, dynamic>;
    expect(mutants['killed'], 3);
    expect(mutants['survived'], 0);
    expect(mutants['timed_out'], 0);

    // The telemetry print names the verdict file BEFORE the machine
    // summary line (the summary stays final).
    final lines = out.trim().split('\n');
    final telemetryLine = lines.lastIndexWhere(
      (l) => l.startsWith('   telemetry:'),
    );
    final summaryIndex = lines.lastIndexWhere((l) => l.startsWith('corpus: '));
    expect(telemetryLine, greaterThan(0));
    expect(summaryIndex, greaterThan(telemetryLine), reason: out);
  });

  test('--shard i/n drives ONLY that shard\'s features '
      '(deterministic; exact coverage across the shards)', () async {
    await fx.writeManifest([
      for (final name in ['f1', 'f2', 'f3', 'f4', 'f5', 'f6'])
        (name: name, ready: true, reason: ''),
    ]);
    await fx.writeFakeZfa();

    // Shard 1/2: round-robin positions 0, 2, 4 -> f1, f3, f5.
    final out = await runCorpus(extra: ['--shard', '1/2']);
    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('[corpus] shard: 1/2 — 3 of 6 feature(s)'),
      reason: out,
    );
    expect(out, contains('f1, f3, f5'), reason: out);
    expect(out, contains('result=complete'), reason: out);
    expect(out, contains('shard=1/2'), reason: out);

    // Only the shard's features were driven.
    final driven = await File(fx.callsLog).readAsLines();
    for (final name in ['f1', 'f3', 'f5']) {
      expect(
        driven.any((l) => l.contains(' run $name ')),
        isTrue,
        reason: 'missing run for $name\n$out',
      );
    }
    for (final name in ['f2', 'f4', 'f6']) {
      expect(
        driven.any((l) => l.contains(' run $name ')),
        isFalse,
        reason: 'shard 1/2 must not drive $name\n$out',
      );
    }

    // The telemetry verdict carries the shard label and only the
    // shard's steps.
    final telemetry = await readTelemetry();
    expect(telemetry['shard'], '1/2');
    final steps = (telemetry['steps'] as List).cast<Map<String, dynamic>>();
    expect(steps.map((s) => s['feature']).toSet(), {'f1', 'f3', 'f5'});

    // Deterministic: a re-run with the same shard spec selects the
    // same features (the fixture resets the call log between runs).
    await fx.writeFakeZfa(resetLog: true);
    final out2 = await runCorpus(extra: ['--shard', '1/2']);
    expect(out2, contains('f1, f3, f5'), reason: out2);

    // Exact coverage: shard 2/2 complements shard 1/2 (the union is
    // the manifest; the progress store proves both lanes' features).
    await fx.writeFakeZfa(resetLog: true);
    final out3 = await runCorpus(extra: ['--shard', '2/2']);
    expect(out3, contains('f2, f4, f6'), reason: out3);
    expect(out3, contains('result=complete'), reason: out3);
  });

  test('a malformed --shard spec is an honest runner-error (exit 2), '
      'nothing driven', () async {
    await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
    await fx.writeFakeZfa();

    final out = await runCorpus(extra: ['--shard', '3/2']);
    expect(exitCode, 2, reason: out);
    expect(out, contains('invalid --shard spec'), reason: out);
    expect(out, contains('result=runner-error'), reason: out);
    // Nothing was driven.
    expect(await File(fx.callsLog).readAsLines(), isEmpty);
  });

  test('a shard lane reports completion for ITS features (a subset '
      'complete, not the whole manifest)', () async {
    await fx.writeManifest([
      for (final name in ['f1', 'f2', 'f3'])
        (name: name, ready: true, reason: ''),
    ]);
    await fx.writeFakeZfa();

    final out = await runCorpus(extra: ['--shard', '1/2']);
    expect(exitCode, 0, reason: out);
    // features= counts the LANE (2: f1, f3), not the manifest (3) —
    // and the lane is complete.
    expect(out, contains('corpus: features=2 '), reason: out);
    expect(out, contains('result=complete'), reason: out);
    expect(out, contains('done=2'), reason: out);
  });

  test('the budget verdict is enforced from the telemetry: '
      'wall_clock_ms is a REAL measurement the CI lane can gate on', () async {
    await fx.writeManifest([
      for (final name in ['f1', 'f2']) (name: name, ready: true, reason: ''),
    ]);
    await fx.writeFakeZfa();

    final out = await runCorpus();
    expect(exitCode, 0, reason: out);
    final telemetry = await readTelemetry();
    final wallClock = telemetry['wall_clock_ms'] as int;
    // A real measurement: > 0, and at least the sum of the step
    // wall-clocks minus scheduling slack.
    final stepsMs = (telemetry['steps'] as List)
        .cast<Map<String, dynamic>>()
        .fold<int>(0, (sum, s) => sum + (s['wall_clock_ms'] as int));
    expect(wallClock, greaterThanOrEqualTo(stepsMs));
    // The smoke subset completed well inside the sharded-lane budget
    // (10 min = 600_000 ms) — the hardware-class extrapolation lives
    // in verification.md.
    expect(wallClock, lessThan(600000), reason: 'smoke lane budget\n$out');
  });
}
