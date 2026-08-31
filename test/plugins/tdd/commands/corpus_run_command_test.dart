@Tags(['slow'])
// Command-level tests for `zfa tdd corpus run` (spec 051-corpus-harness,
// A1/A4 driving, U19-U24 boundaries). The command runs in-process through
// CliRunner.runCapturing; the per-feature `tdd run` / `tdd verify` are the
// fixture's scripted fake zfa binary spawned as real sub-processes (the
// 049 harness pattern, one level up).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  Future<String> drive() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'corpus',
      'run',
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeBin,
    ]);
  }

  Future<Map<String, dynamic>?> progress() => fx.readProgress();

  setUp(() async {
    fx = await CorpusFixture.create();
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A1 — driving in manifest order', () {
    test('drives run-then-verify per feature in manifest order, exit 0',
        () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f2-good', ready: true, reason: ''),
      ]);
      final out = await drive();
      expect(exitCode, 0, reason: out);
      // Order: run+verify per feature, in manifest order.
      expect(await fx.readCalls(), [
        'tdd run f1-good --project ${fx.root.path}',
        'tdd verify --feature f1-good --project ${fx.root.path}',
        'tdd run f2-good --project ${fx.root.path}',
        'tdd verify --feature f2-good --project ${fx.root.path}',
      ]);
      // Progress persisted with both features done.
      final pr = await progress();
      expect(pr!['features']['f1-good']['state'], 'done');
      expect(pr['features']['f2-good']['state'], 'done');
      // The final line is the machine summary.
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        startsWith('corpus: features=2 done=2 waived=0 stopped=0 '
            'not_ready=0 pending=0 dropped=0 gaps=0 result=complete'),
      );
    });
  });

  group('A4 — the gate is recorded', () {
    test('a passing gate marks the feature done with the gate recorded',
        () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
      ]);
      final out = await drive();
      expect(exitCode, 0, reason: out);
      final pr = await progress();
      expect(pr!['features']['f1-good']['gate'], 'pass');
    });
  });

  group('U23 — any run failure stops the corpus', () {
    test('a stopped run halts non-zero with a ledger entry, later features untouched',
        () async {
      await fx.writeFakeZfa(outcomes: {
        'run:f2-gap': (
          exit: 1,
          stdout: [
            'zfa tdd run: step failed — behavior=B-002 step=make outcome=unexpressible',
            'run: feature=f2-gap result=stopped pending=0 red=1 green=0 done=0 stopped_at=B-002:make',
          ],
        ),
      });
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f2-gap', ready: true, reason: ''),
        (name: 'f3-later', ready: true, reason: ''),
      ]);
      final out = await drive();
      expect(exitCode, 1, reason: out);
      final calls = await fx.readCalls();
      // f3 was never started (STOP-ON-ROADBLOCK).
      expect(calls.where((c) => c.contains('f3-later')), isEmpty);
      // f1 completed its whole cycle before the stop.
      expect(
        calls.where((c) => c.contains('f1-good')).toList(),
        hasLength(2),
      );
      // The ledger entry carries the FR-007 fields.
      final ledger = await fx.readLedger();
      expect(ledger, hasLength(1));
      final gap = ledger.first as Map<String, dynamic>;
      expect(gap['feature'], 'f2-gap');
      expect(gap['behavior'], 'B-002');
      expect(gap['step'], 'run');
      expect(gap['outcome'], 'stopped');
      expect(gap['failing_command'], contains('tdd run f2-gap'));
      expect(gap['issue_link'], isNull);
      expect(gap['status'], 'open');
      // The summary names the stopped feature.
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('result=stopped'));
      expect(lastLine, contains('stopped_at=f2-gap'));
      // Progress: f1 done, f2 stopped, f3 untouched (pending).
      final pr = await progress();
      expect(pr!['features']['f1-good']['state'], 'done');
      expect(pr['features']['f2-gap']['state'], 'stopped');
      expect(pr['features']['f2-gap']['stopped_at'], 'B-002:make');
    });
  });

  group('U19 — not-ready features', () {
    test('skipped and reported, never spawned', () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f3-later', ready: false, reason: 'no acceptance scenarios'),
      ]);
      final out = await drive();
      final calls = await fx.readCalls();
      expect(calls.where((c) => c.contains('f3-later')), isEmpty);
      expect(out, contains('no acceptance scenarios'));
      // Not-ready blocks completion (exit 1, result=incomplete).
      expect(exitCode, 1, reason: out);
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('not_ready=1'));
      expect(lastLine, contains('result=incomplete'));
      final pr = await progress();
      expect(pr!['features'].containsKey('f3-later'), isFalse,
          reason: 'never driven, never recorded as driven');
    });
  });

  group('U21 — no manifest', () {
    test('result=no-manifest, exit 2, message names the path', () async {
      final out = await drive();
      expect(exitCode, 2, reason: out);
      expect(out, contains('no corpus manifest'));
      expect(out, contains('corpus-manifest.json'));
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('result=no-manifest'));
      // Nothing was written.
      expect(await progress(), isNull);
      expect(await fx.readLedger(), isEmpty);
    });
  });

  group('U22 — concurrent corpus runs', () {
    test('a live foreign pid in the marker is refused, exit 4', () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
      ]);
      // Seed an in-flight marker owned by a real live process we spawn
      // (pid 1 is not probe-able as a non-root user: kill -0 1 -> EPERM,
      // which the probe correctly treats as not-alive evidence absence).
      final owner = await Process.start('sleep', ['60']);
      try {
        final progressFile = File(fx.progressPath);
        await progressFile.parent.create(recursive: true);
        await progressFile.writeAsString(
          '{"features": {}, "in_flight": {"feature": "f1-good", '
          '"owner_pid": ${owner.pid}}}',
        );
        final out = await drive();
        expect(exitCode, 4, reason: out);
        expect(out, contains('refusing'));
        final lastLine = out.trim().split('\n').last;
        expect(lastLine, contains('result=concurrent-run'));
        // No state writes, no spawns.
        expect(await fx.readCalls(), isEmpty);
        expect(
          await progressFile.readAsString(),
          contains('"owner_pid": ${owner.pid}'),
          reason: 'the progress file was left untouched',
        );
      } finally {
        owner.kill();
        await owner.exitCode.timeout(const Duration(seconds: 5));
      }
    });
  });

  group('U20 + U24 — manifest edited mid-stream', () {
    test('added features are driven; removed features are dropped and reported',
        () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f2-removed', ready: true, reason: ''),
      ]);
      await drive();
      // Edit the manifest: drop f2, add f3.
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f3-added', ready: true, reason: ''),
      ]);
      final out = await drive();
      expect(exitCode, 0, reason: out);
      final calls = await fx.readCalls();
      // f1 not re-driven (resume), f3 driven, f2 never spawned again.
      final f1Calls = calls.where((c) => c.contains('f1-good')).toList();
      expect(f1Calls, hasLength(2), reason: 'only the first run\'s calls');
      expect(
        calls.where((c) => c.contains('f3-added')).toList(),
        hasLength(2),
      );
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('dropped=1'));
      // The dropped feature's progress entry is retained.
      final pr = await progress();
      expect(pr!['dropped'], contains('f2-removed'));
      expect(pr['features'].containsKey('f2-removed'), isTrue);
    });
  });

  group('corrupt state (exit 3 path)', () {
    test('a corrupt progress file stops with the recovery path', () async {
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
      ]);
      final progressFile = File(fx.progressPath);
      await progressFile.parent.create(recursive: true);
      await progressFile.writeAsString('{corrupt');
      final out = await drive();
      expect(exitCode, 3, reason: out);
      expect(out, contains('corrupted'));
      expect(out, contains('Recovery'));
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('result=corrupt-state'));
    });
  });

// ---------------------------------------------------------------------
// A2 + A11 — resume with zero duplicate invocations; resolutions are new
// ledger entries (cycle 8). The skip logic landed with the driving loop
// (cycle 7), so these tests get the deliberate-mutant check: resume
// green on first run is only accepted after breaking the skip proves
// the tests pin it (playbook step 3).
// ---------------------------------------------------------------------



  group('A2 + A11 — resume after a fixed gap', () {
    test('re-run drives 0 duplicates, appends a resolution, history intact',
        () async {
      await fx.writeFakeZfa(outcomes: {
        'run:f2-gap': (
          exit: 1,
          stdout: [
            'run: feature=f2-gap result=stopped pending=0 red=1 green=0 done=0 stopped_at=B-002:make',
          ],
        ),
      });
      await fx.writeManifest([
        (name: 'f1-good', ready: true, reason: ''),
        (name: 'f2-gap', ready: true, reason: ''),
        (name: 'f3-later', ready: true, reason: ''),
      ]);

      // First drive: completes f1, stops at f2 (f3 never started).
      final first = await drive();
      expect(exitCode, 1, reason: first);
      final callsAfterFirst = await fx.readCalls();
      expect(
        callsAfterFirst.where((c) => c.contains('f3-later')),
        isEmpty,
      );
      final ledgerAfterFirst = await File(fx.ledgerPath).readAsString();
      final gapBlock = ledgerAfterFirst.substring(
        ledgerAfterFirst.indexOf('{'),
        ledgerAfterFirst.indexOf('}') + 1,
      );

      // Fix the gap: re-script the fake so f2 succeeds (default lines).
      await fx.rewriteFakeZfa(const {});

      // Re-run: resumes at f2, never re-drives f1.
      final second = await drive();
      expect(exitCode, 0, reason: second);
      final calls = await fx.readCalls();
      final f1Calls = calls.where((c) => c.contains('f1-good')).toList();
      expect(
        f1Calls,
        hasLength(2),
        reason: 'SC-001: 0 duplicate invocations across the resume',
      );
      // f2: the failed run (drive 1) + the resumed run and verify
      // (drive 2) — the stopped feature IS re-driven, by design.
      final f2Calls = calls.where((c) => c.contains('f2-gap')).toList();
      expect(f2Calls, hasLength(3));
      expect(
        f2Calls.where((c) => c.startsWith('tdd run')).toList(),
        hasLength(2),
      );
      expect(calls.where((c) => c.contains('f3-later')).toList(), hasLength(2));

      // A11: the old gap entry is byte-identical; the resolution is a new
      // entry, not an edit.
      final ledgerAfterSecond = await File(fx.ledgerPath).readAsString();
      expect(ledgerAfterSecond, contains(gapBlock));
      final entries = await fx.readLedger();
      expect(entries, hasLength(2));
      expect(entries.first['status'], 'open');
      expect(entries.last['kind'], 'resolution');
      expect(entries.last['resolves'], 'gap-001');
      expect(entries.last['feature'], 'f2-gap');

      // The final summary reports completion.
      final lastLine = second.trim().split('\n').last;
      expect(lastLine, contains('result=complete'));
      expect(lastLine, contains('done=3'));
    });
  });
}
