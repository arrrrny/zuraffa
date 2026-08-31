@Tags(['slow', 'integration'])
// SC-020 — the spec 051 US1 independent test, end to end through the real
// CLI entry point with a scripted fake zfa: a 3-feature fixture corpus
// (one that completes, one that stops on a scripted gap, one not-ready)
// drives, stops, ledgers, and resumes with zero duplicate invocations;
// the runner writes only progress + ledger (the fixture tree is
// checksummed before and after).
//
// T034 (remediation finding 2): the single ~25-assertion test is split
// into phase-scoped tests (drive / stop / ledger / no-edits, then
// resume / history / report) sharing ONE fixture lifecycle — the phases
// are sequential by design (drive -> stop -> fix -> resume), so the
// tests run in declaration order against shared closure state and a
// failing phase names itself in the output.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  // Shared phase state: phase 1 (drive -> stop) produces outputs the
  // phase-2 (resume) assertions must still see; dart runs tests in
  // declaration order within the file, one at a time.
  Map<String, String> specsBefore = const {};
  String firstDrive = '';
  String secondDrive = '';

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

  setUpAll(() async {
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
    specsBefore = await snapshotSpecsTree();
  });

  tearDownAll(() {
    fx.dispose();
    exitCode = 0;
  });

  group('SC-020 phase 1 — drive and stop', () {
    test('drive: f1 run+verified, f2 stops at its run step, exit 1', () async {
      firstDrive = await drive();
      expect(exitCode, 1, reason: firstDrive);
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
    });

    test('FR-003: the not-ready feature is never spawned', () async {
      expect(
        (await fx.readCalls()).where((c) => c.contains('f3-notready')),
        isEmpty,
        reason: 'not-ready features are never spawned',
      );
    });

    test('FR-007: the ledger entry carries the six fields', () async {
      final ledger1 = await fx.readLedger();
      expect(ledger1, hasLength(1));
      final gap = ledger1.first as Map<String, dynamic>;
      expect(gap['feature'], 'f2-gap');
      expect(gap['behavior'], 'B-002');
      expect(gap['step'], 'run');
      expect(gap['outcome'], 'stopped');
      expect(gap['failing_command'], contains('tdd run f2-gap'));
      expect(gap['issue_link'], isNull);
    });

    test(
      'A10: zero test/source edits — specs/ byte-stable, only progress + ledger written',
      () async {
        final after = await snapshotSpecsTree();
        expect(after, specsBefore, reason: 'specs/ tree untouched (A10)');
        final zfaFiles = <String>[];
        final zfaDir = Directory(p.join(fx.root.path, '.zfa', 'corpus'));
        if (await zfaDir.exists()) {
          await for (final entity in zfaDir.list()) {
            if (entity is File) zfaFiles.add(p.basename(entity.path));
          }
        }
        expect(zfaFiles, containsAll(['progress.json', 'gap-ledger.json']));
      },
    );
  });

  group('SC-020 phase 2 — fix and resume', () {
    test(
      'SC-001: resume drives 0 duplicates, f2 re-driven, f3 still never spawned',
      () async {
        // Fix the gap: re-script the fake so f2 succeeds (default lines).
        await fx.rewriteFakeZfa(const {});
        secondDrive = await drive();
        // f3 is still not-ready: reported, blocking completion honestly.
        expect(exitCode, 1, reason: secondDrive);
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
      },
    );

    test('A11: the resolution is a new entry, history intact', () async {
      final ledger2 = await fx.readLedger();
      expect(ledger2, hasLength(2));
      expect(ledger2.first['id'], 'gap-001');
      expect(ledger2.first['status'], 'open');
      expect(ledger2.last['kind'], 'resolution');
      expect(ledger2.last['resolves'], 'gap-001');
    });

    test(
      'report: f1/f2 done, summary honest about the not-ready feature',
      () async {
        final progress = await fx.readProgress();
        expect(progress!['features']['f1-good']['state'], 'done');
        expect(progress['features']['f2-gap']['state'], 'done');
        final lastLine = secondDrive.trim().split('\n').last;
        expect(lastLine, contains('done=2'));
        expect(lastLine, contains('not_ready=1'));
        expect(lastLine, contains('result=incomplete'));
        expect(lastLine, isNot(contains('stopped_at=')));
      },
    );
  });
}
