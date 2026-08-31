// Command-level tests for `zfa tdd corpus audit` (spec
// 051-corpus-harness, A7-A9, U31-U32). The command runs in-process
// through CliRunner.runCapturing; no sub-processes (the audit reads
// evidence files only).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/corpus_fixture.dart';

void main() {
  late CorpusFixture fx;

  Future<String> audit() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'corpus',
      'audit',
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

  Future<void> libFile(String rel) async {
    await write(p.join('lib', rel), '// code\n');
  }

  setUp(() async {
    fx = await CorpusFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A7: 100% attribution exits 0 with report + summary line', () async {
    await libFile('generated.dart');
    await libFile('manual_ui.dart');
    await libFile('main.dart');
    await write('specs/f1/tdd/artifacts.json', jsonEncode({
      'feature': 'f1',
      'records': [
        {
          'behavior_id': 'B-001',
          'feature': 'f1',
          'source_criterion': 'FR-001',
          'test_path': 'test/b_001_test.dart',
          'subject_path': 'lib/generated.dart',
          'runnable_test_name': 't',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': 'x',
        },
      ],
    }));
    await write('.zfa/manifests/corpus-carveout.json', jsonEncode({
      'carveouts': [
        {'path': 'lib/manual_ui.dart', 'reason': 'manual UI (epic 045)'},
      ],
    }));
    await write('.zfa/provenance/setup.json', jsonEncode({
      'command': 'zfa setup demo --specs /corpus',
      'files': ['lib/main.dart'],
    }));

    final out = await audit();
    expect(exitCode, 0, reason: out);
    final lastLine = out.trim().split('\n').last;
    expect(
      lastLine,
      'audit: files=3 attributed=2 carveout=1 unattributed=0 result=pass',
    );
    // The machine-readable report exists with per-file attribution.
    final report = jsonDecode(
      await File(fx.auditReportPath).readAsString(),
    ) as Map<String, dynamic>;
    final files = report['files'] as Map<String, dynamic>;
    expect(files['lib/generated.dart']['source'], 'registry');
    expect(files['lib/main.dart']['source'], 'provenance');
    expect(files['lib/main.dart']['command'], 'zfa setup demo --specs /corpus');
    expect(files['lib/manual_ui.dart']['source'], 'carveout');
    expect(report['counts']['files'], 3);
    expect(report['counts']['unattributed'], 0);
    expect(report['result'], 'pass');
  });

  test('A8: an unattributed file fails the audit BY NAME', () async {
    await libFile('generated.dart');
    await libFile('mystery.dart');
    await write('specs/f1/tdd/artifacts.json', jsonEncode({
      'feature': 'f1',
      'records': [
        {
          'behavior_id': 'B-001',
          'feature': 'f1',
          'source_criterion': 'FR-001',
          'test_path': 'test/t.dart',
          'subject_path': 'lib/generated.dart',
          'runnable_test_name': 't',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': 'x',
        },
      ],
    }));
    final out = await audit();
    expect(exitCode, 1, reason: out);
    expect(out, contains('lib/mystery.dart'));
    final lastLine = out.trim().split('\n').last;
    expect(
      lastLine,
      'audit: files=2 attributed=1 carveout=0 unattributed=1 result=fail',
    );
    final report = jsonDecode(
      await File(fx.auditReportPath).readAsString(),
    ) as Map<String, dynamic>;
    expect(
      (report['unattributed'] as List).single,
      'lib/mystery.dart',
    );
  });

  test('A9: removing a carve-out entry flips its file to unattributed',
      () async {
    await libFile('manual_ui.dart');
    await write('.zfa/manifests/corpus-carveout.json', jsonEncode({
      'carveouts': [
        {'path': 'lib/manual_ui.dart', 'reason': 'manual UI (epic 045)'},
      ],
    }));
    final passing = await audit();
    expect(exitCode, 0, reason: passing);
    expect(
      passing.trim().split('\n').last,
      'audit: files=1 attributed=0 carveout=1 unattributed=0 result=pass',
    );

    // Remove the entry — the manifest is the ONLY exemption path.
    await write('.zfa/manifests/corpus-carveout.json', jsonEncode({
      'carveouts': [],
    }));
    final failing = await audit();
    expect(exitCode, 1, reason: failing);
    expect(failing, contains('lib/manual_ui.dart'));
    expect(
      failing.trim().split('\n').last,
      'audit: files=1 attributed=0 carveout=0 unattributed=1 result=fail',
    );
  });

  test('U32: no lib/ directory audits trivially green with files=0',
      () async {
    final out = await audit();
    expect(exitCode, 0, reason: out);
    expect(
      out.trim().split('\n').last,
      'audit: files=0 attributed=0 carveout=0 unattributed=0 result=pass',
    );
  });
}
