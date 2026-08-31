// Command-level tests for `zfa tdd corpus status` (spec
// 051-corpus-harness, A13-A14, U33-U34). The command runs in-process
// through CliRunner.runCapturing; read-only, no sub-processes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  Future<String> status() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'corpus',
      'status',
      '--project',
      fx.root.path,
    ]);
  }

  Future<File> write(String rel, String content) async {
    final file = File(p.join(fx.root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  setUp(() async {
    fx = await CorpusFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'A13: per-state counts, resume point, ledger totals, read-only',
    () async {
      await fx.writeManifest([
        (name: 'f1-done', ready: true, reason: ''),
        (name: 'f2-stopped', ready: true, reason: ''),
        (name: 'f3-pending', ready: true, reason: ''),
        (name: 'f4-notready', ready: false, reason: 'no acceptance scenarios'),
      ]);
      // Seed progress: f1 done, f2 stopped, f3/f4 untouched.
      await write(
        '.zfa/corpus/progress.json',
        jsonEncode({
          'features': {
            'f1-done': {'state': 'done', 'gate': 'pass'},
            'f2-stopped': {
              'state': 'stopped',
              'gate': 'fail_survived',
              'stopped_at': 'gate:fail_survived',
            },
          },
          'dropped': ['f0-gone'],
        }),
      );
      // Seed a ledger with one open gap for f2.
      await write(
        '.zfa/corpus/gap-ledger.json',
        jsonEncode([
          {
            'id': 'gap-001',
            'kind': 'gap',
            'at': '2026-08-31T00:00:00Z',
            'feature': 'f2-stopped',
            'step': 'verify',
            'outcome': 'fail_survived',
            'expected_result': 'pass',
            'failing_command': 'zfa tdd verify --feature f2-stopped',
            'status': 'open',
          },
        ]),
      );

      // Snapshot every corpus state file: status changes NOTHING.
      final stateFiles = [
        fx.manifestPath,
        fx.progressPath,
        fx.ledgerPath,
        fx.waiversPath,
      ];
      final before = <String, String>{};
      for (final path in stateFiles) {
        final file = File(path);
        before[path] = await file.exists() ? await file.readAsString() : '';
      }

      final out = await status();
      expect(exitCode, 1, reason: 'incomplete corpus -> non-zero (A14)');
      // Per-state counts in the summary line.
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        startsWith(
          'corpus: features=4 done=1 waived=0 stopped=1 '
          'not_ready=1 pending=1 dropped=1 gaps=1 result=incomplete',
        ),
      );
      expect(lastLine, contains('resume_at=f2-stopped'));
      // The report lists the resume point, gate outcomes, ledger totals,
      // and the blocking gap by name.
      expect(out, contains('f2-stopped'));
      expect(out, contains('fail_survived'));
      expect(out, contains('found=1 filed=0 merged=0 blocking=1'));
      expect(out, contains('gap-001'));

      // Read-only: byte-identical state files.
      for (final path in stateFiles) {
        final file = File(path);
        final now = await file.exists() ? await file.readAsString() : '';
        expect(now, before[path], reason: 'status changed $path');
      }
    },
  );

  test(
    'A14: exit 0 exactly when every manifest feature is done|waived',
    () async {
      await fx.writeManifest([
        (name: 'f1-done', ready: true, reason: ''),
        (name: 'f2-waived', ready: true, reason: ''),
      ]);
      await write(
        '.zfa/corpus/progress.json',
        jsonEncode({
          'features': {
            'f1-done': {'state': 'done', 'gate': 'pass'},
            'f2-waived': {
              'state': 'waived',
              'gate': 'not_assessed',
              'waiver': {
                'feature': 'f2-waived',
                'gate': 'not_assessed',
                'reason': 'mutation tool unavailable',
                'actor': 'maintainer',
                'at': '2026-08-31T01:00:00Z',
              },
            },
          },
        }),
      );
      final out = await status();
      expect(exitCode, 0, reason: out);
      final lastLine = out.trim().split('\n').last;
      expect(lastLine, contains('done=1'));
      expect(lastLine, contains('waived=1'));
      expect(lastLine, contains('result=complete'));
      // The waiver is visible with its full record (never silent).
      expect(out, contains('mutation tool unavailable'));
      expect(out, contains('maintainer'));
    },
  );

  test('U34: no manifest -> exit 2 naming the path', () async {
    final out = await status();
    expect(exitCode, 2, reason: out);
    expect(out, contains('no corpus manifest'));
    expect(out.trim().split('\n').last, contains('result=no-manifest'));
  });

  test('U34: corrupt progress -> exit 3 with the recovery path', () async {
    await fx.writeManifest([(name: 'f1', ready: true, reason: '')]);
    await write('.zfa/corpus/progress.json', '{nonsense');
    final out = await status();
    expect(exitCode, 3, reason: out);
    expect(out, contains('Recovery'));
    expect(out.trim().split('\n').last, contains('result=corrupt-state'));
  });

  test('resume_at skips not-ready features in manifest order', () async {
    await fx.writeManifest([
      (name: 'f1-notready', ready: false, reason: 'not imported'),
      (name: 'f2-ready', ready: true, reason: ''),
    ]);
    final out = await status();
    expect(exitCode, 1, reason: out);
    expect(out.trim().split('\n').last, contains('resume_at=f2-ready'));
  });
}
