// SPEC 1119 — `zfa usecase verify <Entity>`: the per-method conformance
// gate + entity drift detection.
//
// The gate re-runs the per-method conformance contract against the
// generated `*_usecase.dart` files: exit 0 when every method's signature
// matches the contract, exit 1 with `--> fix:` lines on drift (the same
// shape `zfa route verify` / `zfa service verify` use). `--json` emits
// ONE canonical `zuraffa.verdict.v1` envelope (issue #1105).
//
// Drift detection (issue #1034 same pattern): the create receipt binds
// the entity source hash (`spec.sha256`); verify exits 1 with an
// `entity_drift` finding when the CURRENT entity source diverges.
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
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_verify_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_verify_test
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

  test('B-001: fresh create → verify exits 0, every method conformant '
      '(json envelope pass)', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['schema'], 'zuraffa.verdict.v1');
    expect(envelope['command'], 'zfa usecase verify Product');
    expect(envelope['verdict'], 'pass');
    expect((envelope['subject'] as Map)['id'], 'Product');
    expect(envelope['findings'] as List, isEmpty);

    final methods =
        ((envelope['details'] as Map<String, dynamic>)['methods'] as List)
            .cast<Map<String, dynamic>>();
    expect(methods.map((m) => m['name']), ['get', 'update']);
    for (final method in methods) {
      expect(method['ok'], isTrue, reason: 'method verdict: $method');
    }
    expect(exitCode, 0);
  });

  test('B-002: tampered execute signature → verify exits 1 with a '
      '`--> fix:` line naming the mismatch (human mode)', () async {
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
      'verify',
      'Product',
    ]);

    expect(exitCode, 1, reason: 'a drifted signature must fail the gate');
    expect(output, contains('[signature_mismatch]'));
    expect(output, contains('--> fix:'));
  });

  test('B-003: deleted execute member → verify exits 1 with '
      'missing_method + fix', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    _tamperFile(workspace.path, 'update_product_usecase.dart', (content) {
      // A class that no longer declares the prescribed execute member.
      return content.replaceFirst(
        'class UpdateProductUseCase',
        'class UpdateProductUseCaseOld ',
      );
    });

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
      '--json',
    ]);

    expect(exitCode, 1);
    final envelope = _parseEnvelope(output);
    expect(envelope['verdict'], 'fail');
    final findings = (envelope['findings'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      findings.map((f) => f['kind']),
      contains('missing_class'),
      reason:
          'renaming the class away leaves the prescribed class missing: '
          '$findings',
    );
    for (final finding in findings) {
      expect(
        (finding['fix'] as String?)?.startsWith('--> fix:'),
        isTrue,
        reason: 'every finding carries a machine-actionable fix line',
      );
    }
  });

  test('B-004: deleted usecase file → verify exits 1 with missing_file '
      '+ fix', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'product',
        'get_product_usecase.dart',
      ),
    ).deleteSync();

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
    ]);

    expect(exitCode, 1);
    expect(output, contains('[missing_file]'));
    expect(output, contains('--> fix:'));
  });

  test('B-005: verify --json emits the canonical envelope as the LAST '
      'stdout line with machine-stable finding kinds', () async {
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
      'verify',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    final findings = (envelope['findings'] as List)
        .cast<Map<String, dynamic>>();
    expect(findings.map((f) => f['kind']), contains('signature_mismatch'));
    for (final finding in findings) {
      expect(finding['file'], isNotNull);
      expect(finding['member'], isNotNull);
    }
    expect((envelope['details'] as Map)['entity'], 'Product');
  });

  test('B-006: verify without an entity is a usage error (exit 2)', () async {
    await runner.runCapturing(['-C', workspace.path, 'usecase', 'verify']);

    expect(exitCode, 2);
  });

  test('B-007: no receipt → verify still gates via conventional file '
      'discovery and reports receiptBound honestly', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    Directory(
      p.join(workspace.path, '.zfa', 'receipts'),
    ).deleteSync(recursive: true);

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['verdict'], 'pass', reason: output);
    final details = envelope['details'] as Map<String, dynamic>;
    expect(details['receiptBound'], isFalse);
    expect(exitCode, 0);
  });

  test('B-010: entity edited after create → verify exits 1 with the '
      'entity_drift finding', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    await File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'entities',
        'product',
        'product.dart',
      ),
    ).writeAsString('''
class Product {
  final String id;
  final String title;

  const Product({required this.id, this.title = 'x'});
}
''');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
    ]);

    expect(exitCode, 1, reason: 'entity hash divergence must fail the run');
    expect(output, contains('entity_drift'));
    expect(output, contains('--> fix:'));
  });

  test('B-011: entity deleted after create → verify exits 1 with '
      'entity_drift', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);
    File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'entities',
        'product',
        'product.dart',
      ),
    ).deleteSync();

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
      '--json',
    ]);

    expect(exitCode, 1);
    final envelope = _parseEnvelope(output);
    expect(envelope['verdict'], 'fail');
    final findings = (envelope['findings'] as List)
        .cast<Map<String, dynamic>>();
    expect(findings.map((f) => f['kind']), contains('entity_drift'));
  });

  test('B-012: untouched entity → no drift verdict', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'verify',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['verdict'], 'pass');
    expect(envelope['drifts'] as List, isEmpty);
    expect(
      ((envelope['details'] as Map)['entityDrift'] as Map?)?['drifted'],
      isFalse,
    );
  });
}

Map<String, dynamic> _parseEnvelope(String output) {
  final lines = output.trim().split('\n').reversed.toList();
  String? envelopeLine;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('{')) {
      envelopeLine = trimmed;
      break;
    }
  }
  expect(envelopeLine, isNotNull, reason: 'no JSON envelope in:\n$output');
  final decoded = jsonDecode(envelopeLine!) as Map<String, dynamic>;
  expect(
    decoded['schema'],
    'zuraffa.verdict.v1',
    reason: 'the envelope must speak the ONE canonical schema:\n$output',
  );
  return decoded;
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
