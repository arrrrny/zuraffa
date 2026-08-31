@Tags(['slow', 'integration'])
// SC-020 — the spec 051 US1 independent test, end to end through the real
// CLI entry point with a scripted fake zfa: a 3-feature fixture corpus
// (one that completes, one that stops on a scripted gap, one not-ready)
// drives, stops, ledgers, and resumes with zero duplicate invocations;
// the runner writes only progress + ledger (the fixture tree is
// checksummed before and after).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  setUp(() async {
    fx = await CorpusFixture.create();
    await fx.writeFakeZfa(
      outcomes: {
        'run:f2-gap': (
          exit: 1,
          stdout: [
            'zfa tdd run: step failed — behavior=B-002 step=make outcome=unexpressible',
            'run: feature=f2-gap result=stopped pending=0 red=1 green=0 done=0 stopped_at=B-002:make',
          ],
        ),
      },
    );
    await fx.writeManifest([
      (name: 'f1-good', ready: true, reason: ''),
      (name: 'f2-gap', ready: true, reason: ''),
      (name: 'f3-notready', ready: false, reason: 'no acceptance scenarios'),
    ]);
    // Loop working files the epic contract requires to exist.
    for (final f in ['f1-good', 'f2-gap', 'f3-notready']) {
      await File(
        p.join(fx.root.path, 'specs', f, 'tdd', 'test-list.md'),
      ).create(recursive: true);
    }
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

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

  /// Checksum of every file under specs/ (the runner must never touch it).
  Future<Map<String, String>> snapshotSpecsTree() async {
    final files = <String, String>{};
    final specsDir = Directory(p.join(fx.root.path, 'specs'));
    await for (final entity in specsDir.list(recursive: true)) {
      if (entity is File) {
        files[p.relative(entity.path, from: fx.root.path)] =
            (await entity.readAsString()).hashCode.toString();
      }
    }
    return files;
  }

  test(
    'SC-020/US1: drive -> stop -> ledger -> resume with 0 duplicates',
    () async {
      final before = await snapshotSpecsTree();

      // --- Drive 1: f1 done+verified, stop at f2, f3 not-ready untouched.
      final first = await drive();
      expect(exitCode, 1, reason: first);
      final calls1 = await fx.readCalls();
      expect(
        calls1.where((c) => c.contains('f1-good')).toList(),
        hasLength(2),
        reason: 'f1 driven run+verify',
      );
      expect(
        calls1.where((c) => c.contains('f2-gap')).toList(),
        hasLength(1),
        reason: 'f2 stopped at its run step',
      );
      expect(
        calls1.where((c) => c.contains('f3-notready')).toList(),
        isEmpty,
        reason: 'not-ready features are never spawned (FR-003)',
      );

      // The ledger entry carries the six FR-007 fields.
      final ledger1 = await fx.readLedger();
      expect(ledger1, hasLength(1));
      final gap = ledger1.first as Map<String, dynamic>;
      expect(gap['feature'], 'f2-gap');
      expect(gap['behavior'], 'B-002');
      expect(gap['step'], 'run');
      expect(gap['outcome'], 'stopped');
      expect(gap['failing_command'], contains('tdd run f2-gap'));
      expect(gap['issue_link'], isNull);

      // The runner wrote ONLY progress + ledger (A10 side: zero
      // test/source edits — the fixture tree is byte-stable).
      final after = await snapshotSpecsTree();
      expect(after, before, reason: 'specs/ tree untouched (A10)');
      final zfaFiles = <String>[];
      final zfaDir = Directory(p.join(fx.root.path, '.zfa', 'corpus'));
      if (await zfaDir.exists()) {
        await for (final entity in zfaDir.list()) {
          if (entity is File) zfaFiles.add(p.basename(entity.path));
        }
      }
      expect(zfaFiles, containsAll(['progress.json', 'gap-ledger.json']));

      // --- Fix the gap and resume: f1 never re-driven.
      await fx.rewriteFakeZfa(const {});
      final second = await drive();
      // f3 is still not-ready: reported, blocking completion honestly.
      expect(exitCode, 1, reason: second);
      final calls2 = await fx.readCalls();
      final f1Total = calls2.where((c) => c.contains('f1-good')).toList();
      expect(
        f1Total,
        hasLength(2),
        reason: 'SC-001: 0 duplicate invocations across the resume',
      );
      expect(
        calls2.where((c) => c.contains('f2-gap')).toList(),
        hasLength(3),
        reason: 'f2: failed run + resumed run + verify',
      );
      expect(
        calls2.where((c) => c.contains('f3-notready')).toList(),
        isEmpty,
        reason: 'still never spawned',
      );

      // The resolution is a new entry; history is intact (A11).
      final ledger2 = await fx.readLedger();
      expect(ledger2, hasLength(2));
      expect(ledger2.first['id'], 'gap-001');
      expect(ledger2.first['status'], 'open');
      expect(ledger2.last['kind'], 'resolution');
      expect(ledger2.last['resolves'], 'gap-001');

      // Progress: f1 and f2 done; the final summary is honest about f3.
      final progress = await fx.readProgress();
      expect(progress!['features']['f1-good']['state'], 'done');
      expect(progress['features']['f2-gap']['state'], 'done');
      final lastLine = second.trim().split('\n').last;
      expect(lastLine, contains('done=2'));
      expect(lastLine, contains('not_ready=1'));
      expect(lastLine, contains('result=incomplete'));
      expect(lastLine, isNot(contains('stopped_at=')));
    },
  );
}
