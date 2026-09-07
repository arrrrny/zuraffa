// SPEC 1119 — `zfa usecase create --certify` and `--explain`.
//
// --certify (mirrors mock's certify): after generation, the verify gate
// runs over the methods the run wired; exit 1 when generation succeeded
// but verify failed; the --json envelope flips to verdict=fail.
//
// --explain: a human-readable block (and the additive `explain` envelope
// key, issue #1122 pattern) describing which methods were generated,
// which variant each uses, which result/params type is bound, which
// exception type is thrown.
//
// The per-method verdict shape on create is UNCHANGED (extend, never
// break) — pinned by B-026.
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
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_cert_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_certify_test
environment:
  sdk: ^3.11.0
''');
    await _scaffoldEntity(workspace.path, 'Product');
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

  test('B-020: create --certify on conformant output exits 0 and states '
      'the certification', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--certify',
    ]);

    expect(exitCode, 0, reason: output);
    expect(output, contains('certified'));
  });

  test('B-021: pre-tampered surface + create --certify exits 1 with the '
      'conformance fix line (generation OK, verify failed)', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    _tamperFile(workspace.path, 'get_product_usecase.dart', (content) {
      return content.replaceFirst('Future<Product>', 'Future<String>');
    });

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--certify',
    ]);

    expect(exitCode, 1, reason: 'certify must fail the run on drift');
    expect(output, contains('[signature_mismatch]'));
    expect(output, contains('--> fix:'));
  });

  test('B-022: create --certify --json flips the envelope to fail with '
      'findings when the gate fails', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    _tamperFile(workspace.path, 'update_product_usecase.dart', (content) {
      return content.replaceFirst('Future<Product>', 'Future<String>');
    });

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--certify',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['schema'], 'zuraffa.verdict.v1');
    expect(envelope['command'], 'zfa usecase create Product');
    expect(envelope['verdict'], 'fail');
    final findings = (envelope['findings'] as List)
        .cast<Map<String, dynamic>>();
    expect(findings.map((f) => f['kind']), contains('signature_mismatch'));
    expect(exitCode, 1);
  });

  test('B-023: the certified create receipt records the certification '
      'outcome', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--certify',
    ]);

    final receipt = _latestReceipt(workspace.path, 'Product');
    expect(receipt['input']['certify'], isTrue);
    expect(receipt['input']['certification'], 'pass');
  });

  test('B-024: create --explain (human) prints the block — variants, '
      'result types, exception type', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--methods=get,delete,watch',
      '--explain',
    ]);

    expect(exitCode, 0, reason: output);
    expect(output, contains('Explain'));
    // The future variant.
    expect(output, contains('GetProductUseCase'));
    expect(output, contains('Future<Product>'));
    // The completable (void) variant.
    expect(output, contains('DeleteProductUseCase'));
    expect(output, contains('Future<void>'));
    // The stream variant.
    expect(output, contains('WatchProductUseCase'));
    expect(output, contains('Stream<Product>'));
    // The exception contract.
    expect(output, contains('CancelledException'));
  });

  test('B-025: create --explain --json carries the additive explain '
      'block; base envelope keys unchanged', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--explain',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['schema'], 'zuraffa.verdict.v1');
    expect(envelope['verdict'], 'pass');
    final explain = envelope['explain'] as Map<String, dynamic>?;
    expect(
      explain,
      isNotNull,
      reason:
          'the explain block must ride the '
          'additive envelope key (issue #1122 pattern):\n$output',
    );
    final methods = (explain!['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods.map((m) => m['name']), ['get', 'update']);
    for (final method in methods) {
      expect(method['class'], isNotNull);
      expect(method['variant'], isIn(['future', 'stream', 'void']));
      expect(method['resultType'], isNotNull);
      expect(method['exception'], 'CancelledException');
    }
  });

  test('B-026: per-method verdict shape unchanged with --certify '
      '--explain (name/action/reason only — extend, never break)', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--certify',
      '--explain',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    final methods =
        ((envelope['details'] as Map<String, dynamic>)['methods'] as List)
            .cast<Map<String, dynamic>>();
    expect(methods, hasLength(2));
    for (final method in methods) {
      expect(
        method.keys.toSet(),
        equals({'name', 'action'}),
        reason: 'fresh-create verdicts keep the exact #972 shape: $method',
      );
      expect(method['action'], 'created');
    }
    expect(exitCode, 0);
  });
}

Map<String, dynamic> _parseEnvelope(String output) {
  final trimmed = output.trim();
  expect(
    trimmed.startsWith('{'),
    isTrue,
    reason: '--json mode must print only the JSON envelope:\n$output',
  );
  return jsonDecode(trimmed) as Map<String, dynamic>;
}

Map<String, dynamic> _latestReceipt(String projectRoot, String entity) {
  final receiptsDir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
  final files =
      receiptsDir
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                p.basename(f.path).startsWith('usecase-create-$entity-') &&
                p.basename(f.path).endsWith('.json'),
          )
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  expect(files, isNotEmpty, reason: 'a create run must ship a receipt');
  return jsonDecode(files.last.readAsStringSync()) as Map<String, dynamic>;
}

void _tamperFile(
  String projectRoot,
  String fileName,
  String Function(String content) mutate,
) {
  final file = File(
    p.join(
      projectRoot,
      'lib',
      'src',
      'domain',
      'usecases',
      'product',
      fileName,
    ),
  );
  final content = file.readAsStringSync();
  final mutated = mutate(content);
  expect(mutated, isNot(content), reason: 'the tamper must change bytes');
  file.writeAsStringSync(mutated);
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
