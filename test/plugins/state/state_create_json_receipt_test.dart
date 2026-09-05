// Spec 976 (issue #976) — `zfa state create --json` verdict envelope +
// proof.v1 receipt.
//
// `zfa state create` must speak to automation: the last stdout line
// under `--json` is a single-line envelope
// `{path, fields[], modes[], flavor, schema:1}`, and every real
// generation ships a receipt at `.zfa/receipts/state-<entity>.json`
// (via ReceiptStore) binding the final on-disk bytes, so `zfa proof
// check` covers state artifacts (SC-2, AC-2).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_state_json_');
    // A pure-Dart pubspec pins the flavor: the envelope must report
    // `pureDart` and the state must import zuraffa core (#512).
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: state_json_ws
publish_to: none
environment:
  sdk: ^3.11.0
''');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() async {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  test('SC-2a: --json emits the {path, fields[], modes[], flavor, schema:1} '
      'envelope as the last stdout line', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'state',
      'create',
      '--name',
      'Product',
      '--methods',
      'get,getList',
      '--json',
    ]);

    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    expect(lines, isNotEmpty);
    final last = lines.last;

    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(last) as Map<String, dynamic>;
    } catch (e) {
      fail(
        'the last stdout line must be a single-line JSON envelope, got: '
        '"$last" ($e)\nfull output:\n$output',
      );
    }

    expect(
      envelope['schema'],
      1,
      reason: 'the envelope carries integer schema version 1',
    );
    expect(
      envelope['path'],
      'lib/src/presentation/pages/product/product_state.dart',
      reason: 'path is project-relative POSIX, agent-consumable',
    );
    expect(
      envelope['fields'],
      containsAll(<String>[
        'error',
        'product',
        'productList',
        'offset',
        'limit',
        'hasMore',
        'isGetting',
        'isGettingList',
      ]),
      reason: 'fields list the emitted state fields (declaration order)',
    );
    expect(
      envelope['fields'] is List && (envelope['fields'] as List).isNotEmpty,
      isTrue,
    );
    expect(envelope['modes'], [
      'entity',
    ], reason: 'the entity emission mode is reported as a list');
    expect(envelope['flavor'], 'pureDart');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('SC-2b: a real generation ships a proof.v1 receipt at '
      '.zfa/receipts/state-<entity>.json binding the final bytes', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'state',
      'create',
      '--name',
      'Product',
      '--methods',
      'get,getList',
      '--json',
    ]);
    expect(
      output,
      isNot(contains('❌')),
      reason:
          'generation must succeed for the receipt to be written:\n'
          '$output',
    );

    final receiptFile = File(
      p.join(workspace.path, '.zfa', 'receipts', 'state-Product.json'),
    );
    expect(
      receiptFile.existsSync(),
      isTrue,
      reason:
          'the receipt lives at .zfa/receipts/state-<entity>.json '
          '(written via ReceiptStore)',
    );

    final receipt = GenerationReceipt.fromJson(
      jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>,
    );
    expect(receipt.schema, 'proof.v1');
    expect(receipt.command, 'state create');
    expect(receipt.target, 'Product');
    expect(receipt.repro, contains('zfa state create'));
    expect(receipt.generatorVersion, isNotEmpty);
    expect(receipt.input['name'], 'Product');

    expect(receipt.files, hasLength(1));
    final entry = receipt.files.single;
    expect(entry.path, 'lib/src/presentation/pages/product/product_state.dart');
    expect(entry.action, 'create');

    final disk = File(p.join(workspace.path, entry.path));
    expect(disk.existsSync(), isTrue);
    expect(
      entry.sha256,
      crypto.sha256.convert(disk.readAsBytesSync()).toString(),
      reason: 'the receipt digests the final on-disk bytes',
    );
    expect(entry.bytes, disk.lengthSync());
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('SC-2c: zfa proof check covers the state artifact (green on a fresh '
      'generation)', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'state',
      'create',
      '--name',
      'Product',
      '--methods',
      'get,getList',
    ]);

    final proofOutput = await runner.runCapturing([
      '-C',
      workspace.path,
      'proof',
      'check',
      '--format=json',
    ]);
    final report = jsonDecode(proofOutput) as Map<String, dynamic>;
    expect(
      report['ok'],
      isTrue,
      reason: 'a fresh state generation must verify green:\n$proofOutput',
    );
    expect(
      report['filesChecked'],
      greaterThanOrEqualTo(1),
      reason: 'the state artifact is covered by the receipt',
    );
    expect(report['findings'], isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'SC-2d: proof check goes red when a receipted state artifact drifts',
    () async {
      await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'create',
        '--name',
        'Product',
        '--methods',
        'get,getList',
      ]);

      final stateFile = File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'presentation',
          'pages',
          'product',
          'product_state.dart',
        ),
      );
      await stateFile.writeAsString(
        '// hand-edited drift\n${await stateFile.readAsString()}',
      );

      final proofOutput = await runner.runCapturing([
        '-C',
        workspace.path,
        'proof',
        'check',
        '--format=json',
      ]);
      final report = jsonDecode(proofOutput) as Map<String, dynamic>;
      expect(
        report['ok'],
        isFalse,
        reason:
            'drifted state bytes must fail the proof check:\n'
            '$proofOutput',
      );
      final findings = (report['findings'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        findings.any(
          (f) =>
              f['kind'] == 'modified' &&
              (f['path'] as String).endsWith('product_state.dart'),
        ),
        isTrue,
        reason: 'the finding names the drifted state artifact',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'SC-2e: without --json the human output is unchanged (no envelope)',
    () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'create',
        '--name',
        'Product',
        '--methods',
        'get,update',
      ]);
      expect(output, contains('product_state.dart'));

      final lastLine = output
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .last;
      final isEnvelope =
          lastLine.startsWith('{') &&
          lastLine.endsWith('}') &&
          lastLine.contains('"schema"');
      expect(
        isEnvelope,
        isFalse,
        reason:
            'the JSON verdict must appear ONLY under --json; the default '
            'path keeps the human summary:\n$output',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
