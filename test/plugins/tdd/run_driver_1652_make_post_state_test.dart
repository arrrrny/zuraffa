// Issue #1652 — driver-level contract: the driving run records make's
// certified post-state (`tdd/make-post-state.json`) the moment a make
// step green-applies, so the immediately-following `--pass-batch`
// refactor spawn can inherit the pipeline instead of re-paying it (see
// the command-level suite: bug_1652_refactor_make_post_state_test.dart).
//
// Contracts pinned here (the run_command_test harness shape — the step
// commands are the fixture's scripted fake zfa spawned as real
// sub-processes):
//   U5a — a green make writes the record with tree-matching digests and
//         an honest verdict naming the behavior.
//   U5b — the #741 already-green skip writes NOTHING: the standing
//         record still describes the certified tree.
//   U5c — a write failure is a warning, never an error: the run
//         completes (the next refactor pays one full pipeline).
//   U6  — the record is derived data describing ONE moment: after a
//         later tree change its digests no longer match (inert stale).

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/pass_batch_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '091-make-post-state';

  Future<String> drive() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  File recordFile() =>
      File(p.join(fx.featureDir, 'tdd', 'make-post-state.json'));

  Future<Map<String, dynamic>> readRecord() async =>
      jsonDecode(await recordFile().readAsString()) as Map<String, dynamic>;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-002',
        description: 'second behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('U5a: a green make records the certified post-state — digests '
      'match the on-disk trees, the verdict names the behavior', () async {
    final out = await drive();

    expect(exitCode, 0, reason: out);
    final record = await readRecord();
    expect(record['behavior_id'], isA<String>());
    expect(record['suite'], isA<String>());
    // No baseline was handed to the run: the key is the empty-string
    // shape; the config key is always materialized.
    expect(record['baseline_key'], '');
    expect(record['config_key'], isNotEmpty);
    expect(record['exempt_behaviors'], isEmpty);
    // The digests describe the CURRENT tree — recompute and compare.
    final libNow = await TreeSnapshot.capture(
      fx.root.path,
      trees: const ['lib'],
    );
    final testNow = await TreeSnapshot.capture(
      fx.root.path,
      trees: const ['test'],
    );
    expect(record['lib_digest'], PassBatchLedger.treeDigest(libNow));
    expect(record['test_digest'], PassBatchLedger.treeDigest(testNow));
    // The green verdict names the behavior whose make certified it.
    final verdict = record['green_verdict'] as String;
    expect(verdict, contains('make'));
    expect(verdict, contains('outcome=green'));
    // The last green make of the run is the recorder (B-002).
    expect(record['behavior_id'], 'B-002', reason: verdict);
  });

  test('U5b: the #741 already-green skip writes nothing — the standing '
      'record keeps describing the certified tree', () async {
    // B-001's make green-applies (records); B-002's verify-red reports
    // unexpected-green and its make reports the #694/#741 skip
    // transition (the tree untouched by that make).
    await fx.setStepOutcome('verify-red', 'B-002', 'unexpected-green');
    await fx.setStepOutcome('make', 'B-002', 'skip');
    await fx.seedRedEvidence('B-002');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    final record = await readRecord();
    // The recorder is B-001's GREEN make — B-002's skip did not
    // overwrite it (a skip certifies no new tree state).
    expect(record['behavior_id'], 'B-001', reason: out);
  });

  test(
    'U5c: a record write failure is a warning — the run completes',
    () async {
      // A directory where the record must land: every write fails.
      await recordFile().parent.create(recursive: true);
      await Directory(recordFile().path).create(recursive: true);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // The failure is named, with the cost stated honestly — never a
      // silent drop, never a run failure.
      expect(out, contains('make-post-state'));
      expect(out, contains('could not be written'));
      expect(out, contains('result=complete'), reason: out);
    },
  );

  test('U6: the record describes one moment — a later tree change makes '
      'its digests stale (inert)', () async {
    await drive();
    final record = await readRecord();

    // A later step (or make) changes the tree after the record.
    await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
    await File(
      p.join(fx.root.path, 'lib', 'later_subject.dart'),
    ).writeAsString('int later() => 1;\n');

    final libNow = await TreeSnapshot.capture(
      fx.root.path,
      trees: const ['lib'],
    );
    expect(
      record['lib_digest'],
      isNot(PassBatchLedger.treeDigest(libNow)),
      reason:
          'a stale record must never match the moved-on tree — the '
          'digest mismatch is what sends the next refactor through the '
          'full pipeline',
    );
    // The record itself was not rewritten by the drift.
    expect(await readRecord(), record);
  });
}
