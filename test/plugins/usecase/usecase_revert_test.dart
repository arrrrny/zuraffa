// Spec #972 — the revert path for `zfa usecase create` (FR-6, revert).
//
// `zfa usecase create <E> --revert` deletes the generated usecase files
// (per-method when --methods is explicit, the canonical set otherwise),
// reports `deleted` verdicts in --json mode, and writes NO receipt —
// nothing was generated, so there is nothing to prove (mirrors the make
// receipt contract: dry-run and revert runs do not ship receipts). The
// create-run receipt outlives its artifacts exactly like make's do, so
// `zfa proof check` keeps reporting them as deleted.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_rev_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_revert_test
environment:
  sdk: ^3.11.0
''');
    runner = CliRunner(exitOnCompletion: false);
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('create then revert deletes the emitted usecase files, reports '
      'deleted verdicts, and ships no receipt', () async {
    await _scaffoldEntity(workspace.path, 'Product');

    // 1. Generate the default set (get, update).
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    final usecaseDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'product'),
    );
    expect(
      usecaseDir.listSync().map((e) => p.basename(e.path)).toList(),
      isNotEmpty,
      reason: 'generation must have emitted files before the revert',
    );
    final receiptPath = p.join(
      workspace.path,
      '.zfa',
      'receipts',
      'usecase-Product.json',
    );
    expect(File(receiptPath).existsSync(), isTrue);

    // 2. Revert.
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--revert',
      '--json',
    ]);

    final envelope = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(envelope['schema'], 1);
    final methods = (envelope['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, isNotEmpty);
    for (final verdict in methods) {
      expect(
        verdict['action'],
        'deleted',
        reason: 'revert verdicts are honest about deletion: $methods',
      );
    }

    // 3. The files are gone from disk.
    expect(
      File(p.join(usecaseDir.path, 'get_product_usecase.dart')).existsSync(),
      isFalse,
      reason: 'get usecase must be deleted',
    );
    expect(
      File(p.join(usecaseDir.path, 'update_product_usecase.dart')).existsSync(),
      isFalse,
      reason: 'update usecase must be deleted',
    );

    // 4. The revert run writes no receipt of its own — the create-run
    //    receipt remains (mirroring make semantics: proofs outlive their
    //    artifacts so `zfa proof check` can report them as deleted), but
    //    a revert must never claim generation.
    final receipt =
        jsonDecode(await File(receiptPath).readAsString())
            as Map<String, dynamic>;
    expect(receipt['command'], 'usecase');
    final filesAfterRevert = (receipt['files'] as List)
        .cast<Map<String, dynamic>>()
        .map((f) => f['path'] as String)
        .toList();
    expect(
      filesAfterRevert.any((f) => f.endsWith('get_product_usecase.dart')),
      isTrue,
      reason:
          'the pre-revert receipt is the create run\'s, untouched: '
          '$filesAfterRevert',
    );

    // 5. Proof check notices the artifacts are gone (deleted findings) —
    //    the receipt system remains honest about the revert.
    final proofOutput = await runner.runCapturing([
      '-C',
      workspace.path,
      'proof',
      'check',
      '--format=json',
    ]);
    expect(proofOutput, contains('"kind":"deleted"'));
  });

  test('reverting with nothing generated is a quiet success', () async {
    await _scaffoldEntity(workspace.path, 'Ghost');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Ghost',
      '--revert',
      '--json',
    ]);

    final envelope = jsonDecode(output.trim()) as Map<String, dynamic>;
    final methods = (envelope['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, isNotEmpty);
    for (final verdict in methods) {
      expect(
        verdict['action'],
        'skipped',
        reason:
            'nothing was generated, so nothing could be deleted: '
            '$methods',
      );
    }
    expect(exitCode, 0, reason: 'nothing to delete is not an error:\n$output');
  });
}

Future<void> _scaffoldEntity(String projectRoot, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory(
    p.join(projectRoot, 'lib', 'src', 'domain', 'entities', snake),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, '$snake.dart')).writeAsString('''
class $entityName {
  final String id;

  const $entityName({required this.id});
}
''');
}

String _camelToSnake(String input) => input
    .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
    .replaceFirst(RegExp(r'^_'), '');
