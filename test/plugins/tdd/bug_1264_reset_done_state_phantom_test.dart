@Tags(['slow'])
// Bug #1264 — `zfa tdd reset <feature>` leaves done-state for deleted
// artifacts: doctor says healthy, run skips the behaviors, status
// reports engine green on nonexistent tests.
//
// RED evidence: reset deletes the owned test/subject files, the registry
// and run-state, but the cycle-log green evidence and the lane receipts
// SURVIVE (reset never touches append-only evidence). The run driver
// then re-derives done from that surviving evidence (the bug-682
// bootstrap), doctor only checks store-to-store agreement (never
// store-to-tree), and status trusts the stale receipt — the issue's
// exact phantom: `2 already done — skipping`, doctor healthy, engine
// ✅ 2/2 on nonexistent tests.
//
// The fix under test:
// (a) reset appends a tombstone journal entry invalidating the dropped
//     behaviors' evidence (per-behavior invalidation, append-only);
// (b) the run driver does not honor tombstoned green evidence — the
//     dropped behaviors re-drive from gen;
// (c) doctor reports `evidence-without-artifact` as a drift and
//     prescribes exactly one recovery (`zfa tdd run <feature>`);
// (d) status does not report green for behaviors whose green evidence
//     has no backing test file on disk.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-1264';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The last non-empty stdout line — the recovery commands' JSON
  /// verdict contract.
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  String journalPath() => p.join(fx.featureDir, 'tdd', 'journal.json');

  /// The issue's completed-feature state: two engine behaviors with
  /// registered test+subject files on disk, red+green evidence in the
  /// cycle log, a done run-state, and a green engine receipt —
  /// everything reset owns plus the evidence that survives it.
  Future<void> seedCompletedFeature() async {
    for (final id in const ['U-001', 'U-002']) {
      await fx.registerBehavior(id: id, description: 'the $id behavior');
      final subject = File(fx.subjectPathOf(id));
      await subject.parent.create(recursive: true);
      await subject.writeAsString('library;\n\nint value() => 42;\n');
      await fx.seedRedEvidence(id);
      await fx.seedGreenEvidence(id);
    }
    await fx.seedRunState(states: {'U-001': 'done', 'U-002': 'done'});
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(
      p.join(fx.featureDir, 'tdd', '04-engine-receipt.json'),
    ).writeAsString(
      jsonEncode({
        'schema': 1,
        'feature': feature,
        'lane': 'engine',
        'verdict': 'green',
        'result': 'complete',
        'behaviors': ['U-001', 'U-002'],
        'counts': {'total': 2, 'pending': 0, 'red': 0, 'green': 0, 'done': 2},
        'stopped_at': null,
        'at': '2026-08-30T00:00:00.000Z',
      }),
    );
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: 'U-001',
        description: 'the first behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U-002',
        description: 'the second behavior',
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

  group('bug 1264 (a): reset tombstones the dropped behaviors', () {
    test('reset appends a journal tombstone invalidating the dropped '
        'behaviors green evidence', () async {
      await seedCompletedFeature();

      final out = await runCli(['reset', feature]);

      expect(exitCode, 0, reason: out);
      expect(File(journalPath()).existsSync(), isTrue, reason: out);
      final journal =
          jsonDecode(await File(journalPath()).readAsString())
              as Map<String, dynamic>;
      final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
      final tombstones = entries.where((e) => e['phase'] == 'reset').toList();
      expect(tombstones, hasLength(1), reason: out);
      expect(tombstones.single['cycle'], 'meta', reason: out);
      expect(tombstones.single['result'], 'reset', reason: out);
      expect(tombstones.single['behaviors'], ['U-001', 'U-002'], reason: out);
    });
  });

  group('bug 1264 (c): doctor detects evidence-without-artifact', () {
    test('doctor reports the phantom done-state as a drift and prescribes '
        'exactly one recovery', () async {
      await seedCompletedFeature();
      await runCli(['reset', feature]);

      final out = await runCli(['doctor', feature]);

      // Post-reset the files are gone but the green evidence survives:
      // store-to-tree disagreement — never healthy.
      expect(exitCode, 1, reason: out);
      expect(out, contains('evidence-without-artifact'), reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('zfa tdd run $feature'), reason: out);
      final v = verdict(out);
      expect(v['verdict'], 'drift', reason: out);
      expect(v['prescription'], 'resume', reason: out);
    });

    test(
      'doctor stays healthy when the green evidence is backed by files',
      () async {
        await seedCompletedFeature();

        final out = await runCli(['doctor', feature]);

        expect(exitCode, 0, reason: out);
        final v = verdict(out);
        expect(v['verdict'], 'healthy', reason: out);
      },
    );
  });

  group('bug 1264 (b): run re-drives the dropped behaviors', () {
    test('run does not skip the dropped behaviors — it re-drives them from '
        'gen', () async {
      await seedCompletedFeature();
      await runCli(['reset', feature]);
      fx.clearStepInvocations();

      final out = await runCli(['run', feature, '--zfa-bin', fx.fakeZfaBin]);

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), [
        'gen U-001',
        'verify-red U-001',
        'make U-001',
        'refactor U-001',
        'gen U-002',
        'verify-red U-002',
        'make U-002',
        'refactor U-002',
      ], reason: out);
      expect(out, isNot(contains('already done')), reason: out);
    });
  });

  group('bug 1264 (d): status does not report green without files', () {
    test(
      'status demotes the stale green engine receipt and names the drift',
      () async {
        await seedCompletedFeature();
        await runCli(['reset', feature]);

        final out = await runCli(['status', feature]);

        expect(exitCode, 1, reason: out);
        expect(out, contains('engine=red'), reason: out);
        expect(out, contains('evidence-without-artifact'), reason: out);
      },
    );
  });
}
