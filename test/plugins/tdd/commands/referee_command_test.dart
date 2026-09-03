// U14-U16 (spec 070): the `zfa tdd referee` command family — the golden
// workflow verdict (FR-001), the publishing gate (FR-004/005), and the
// provenance rollup (FR-003/012). Runs in-process through
// CliRunner.runCapturing; read-only over the recorded infrastructure.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

void main() {
  late Directory root;

  Future<File> write(String rel, String content) async {
    final file = File(p.join(root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  Future<void> writeFeature({
    required String feature,
    required String subject,
    bool simulated = false,
  }) async {
    await write(
      'specs/$feature/tdd/artifacts.json',
      jsonEncode({
        'records': [
          {
            'behavior_id': 'B-001',
            'feature': feature,
            'source_criterion': 'FR-001',
            'test_path': 'test/${feature}_test.dart',
            'subject_path': subject,
            'runnable_test_name': 'file::B-001::does it',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-09-01T00:00:00Z',
          },
        ],
      }),
    );
    final content = 'class S {}\n';
    await write(subject, content);
    await write(
      'specs/$feature/tdd/cycle-log.md',
      '## Cycle: B-001 (green)\n\n- behavior: B-001\n- kind: green\n',
    );
    if (simulated) {
      await write(
        'specs/$feature/tdd/fixtures/manifest.json',
        jsonEncode({
          'families': ['rest'],
          'digest': 'x',
          'files': [],
        }),
      );
    }
    final store = ReceiptStore(projectRoot: root.path);
    await store.save(
      GenerationReceipt(
        command: 'tdd-gen',
        target: feature,
        repro: 'zfa tdd gen',
        at: DateTime.utc(2026, 9, 2),
        generatorVersion: '6.1.0',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: subject,
            action: 'create',
            sha256: sha256.convert(content.codeUnits).toString(),
            bytes: content.length,
          ),
        ],
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('referee_cmd_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<String> run(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'referee',
      ...args,
      '--project',
      root.path,
    ]);
  }

  test('U14: `referee run` prints the machine verdict line and the markdown '
      'comment (dry-run default)', () async {
    await writeFeature(feature: 'f-a', subject: 'lib/a.dart');

    final output = await run(['run']);

    expect(output, contains('## CI Referee Verdict'));
    expect(output, contains('| Feature | State |'));
    expect(output, contains('Exit protocol'));
    // The machine line.
    expect(output, contains('referee:'));
    expect(output, contains('result=pass'));
    // Dry-run is the default: no posting, comment rendered inline.
    expect(output, contains('f-a'));
  });

  test('U14: a doc-only PR (no feature files changed) renders the minimal '
      'verdict (FR-008)', () async {
    await writeFeature(feature: 'f-a', subject: 'lib/a.dart');
    final changed = await write('changed-files.txt', 'README.md\n');

    final output = await run(['run', '--changed-files', changed.path]);

    expect(output, contains('no feature provenance was affected'));
    expect(output, isNot(contains('| Feature |')));
    expect(output, contains('result=pass'));
  });

  test('U15: `referee gate` exits 0 for an all-real corpus and 1 when '
      'mocked/intermediate features block production', () async {
    await writeFeature(feature: 'f-real', subject: 'lib/real.dart');

    final ok = await run(['gate']);
    expect(ok, contains('result=production'));
    expect(exitCode, 0, reason: 'all-real passes the production gate');

    // Now a mocked feature joins the corpus: simulation offered,
    // exit 1.
    await writeFeature(
      feature: 'f-mock',
      subject: 'lib/mock.dart',
      simulated: true,
    );
    final blocked = await run(['gate']);
    expect(blocked, contains('result=simulation'));
    expect(blocked, contains('simulation'));
    expect(exitCode, 1, reason: 'production blocked, simulation labeled');
  });

  test('U16: `referee rollup` writes the rollup document and archives the '
      'previous one (FR-003/FR-012)', () async {
    await writeFeature(feature: 'f-real', subject: 'lib/real.dart');

    final first = await run(['rollup']);
    expect(first, contains('rollup:'));
    expect(first, contains('generated=100%'));
    expect(
      await File(
        p.join(root.path, '.zfa', 'corpus', 'provenance-rollup.json'),
      ).exists(),
      isTrue,
    );

    // A second feature appears → regeneration archives the previous.
    await writeFeature(feature: 'f-more', subject: 'lib/more.dart');
    final second = await run(['rollup']);
    expect(second, contains('archived=1'));
    expect(
      Directory(
        p.join(root.path, '.zfa', 'corpus', 'provenance-archive'),
      ).listSync().whereType<File>(),
      isNotEmpty,
    );
  });
}
