// Spec #972 — `zfa usecase create --json` per-method verdicts (FR-2) and
// the generation receipt (FR-3).
//
// The --json envelope is the machine contract:
//   {"schema": 1, "entity": ..., "methods": [
//      {"name": "get", "action": "created"},
//      {"name": "toggle", "action": "skipped", "reason": "..."}]}
// with action ∈ {created, appended, skipped} (deleted on the revert path).
//
// The receipt lands at .zfa/receipts/usecase-<entity>.json (proof.v1):
// requested vs generated vs skipped methods + guard reason codes, with
// per-file digests, so `zfa proof check` can verify it end-to-end.
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
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_json_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_json_test
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

  test('FR-2: fresh create emits per-method verdicts and a proof-checkable '
      'receipt', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    expect(envelope['schema'], 1);
    expect(envelope['entity'], 'Product');

    final methods = (envelope['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, hasLength(2), reason: 'default methods: get, update');
    expect(
      methods.first['name'],
      'get',
      reason: 'requested order is preserved',
    );
    expect(methods.first['action'], 'created');
    expect(methods.last['name'], 'update');
    expect(methods.last['action'], 'created');

    // The receipt: requested vs generated vs skipped + guard codes.
    final receiptPath = p.join(
      workspace.path,
      '.zfa',
      'receipts',
      'usecase-Product.json',
    );
    expect(
      File(receiptPath).existsSync(),
      isTrue,
      reason: 'receipt must land at .zfa/receipts/usecase-<entity>.json',
    );
    final receipt =
        jsonDecode(await File(receiptPath).readAsString())
            as Map<String, dynamic>;
    expect(receipt['schema'], 'proof.v1');
    expect(receipt['command'], 'usecase');
    expect(receipt['target'], 'Product');
    expect(receipt['repro'], contains('zfa usecase create Product'));

    final input = receipt['input'] as Map<String, dynamic>;
    expect(input['requested_methods'], ['get', 'update']);
    expect(input['generated_methods'], ['get', 'update']);
    expect(input['skipped_methods'], isEmpty);
    expect(
      input['guard_reason_codes'],
      isA<Map>(),
      reason: 'guard codes map present even when empty',
    );

    // The generated files are digest-bound.
    final files = (receipt['files'] as List)
        .cast<Map<String, dynamic>>()
        .map((f) => f['path'] as String)
        .toList();
    expect(
      files.any((f) => f.endsWith('get_product_usecase.dart')),
      isTrue,
      reason: 'receipt files: $files',
    );

    // The receipt is proof-checkable: digests must verify green.
    final proofOutput = await runner.runCapturing([
      '-C',
      workspace.path,
      'proof',
      'check',
      '--format=json',
    ]);
    expect(
      proofOutput,
      contains('"ok":true'),
      reason: 'fresh usecase generation must be provable:\n$proofOutput',
    );
  });

  test('FR-2: re-running create is honest — already-present methods are '
      'skipped, not re-created', () async {
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
      'create',
      'Product',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    final methods = (envelope['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, hasLength(2));
    for (final verdict in methods) {
      expect(
        verdict['action'],
        'skipped',
        reason: 'idempotent re-run must not claim creation: $methods',
      );
      expect(
        (verdict['reason'] as String?) ?? '',
        contains('already'),
        reason: 'skip verdicts carry a reason code: $verdict',
      );
    }
    expect(exitCode, 0, reason: 'an idempotent re-run is a success');
  });

  test('FR-2/FR-3: guard-dropped methods are reported as skipped with a '
      'reason code, in the envelope AND the receipt', () async {
    await _scaffoldRepository(workspace.path, 'Task', ['get', 'update']);
    await _scaffoldEntity(workspace.path, 'Task');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Task',
      '--methods=get,toggle',
      '--json',
    ]);

    final envelope = _parseEnvelope(output);
    final methods = (envelope['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, hasLength(2));

    final get = methods.firstWhere((m) => m['name'] == 'get');
    expect(get['action'], 'created');

    final toggle = methods.firstWhere((m) => m['name'] == 'toggle');
    expect(toggle['action'], 'skipped');
    expect(
      toggle['reason'].toString(),
      contains('interface_missing_method'),
      reason: 'guard reason codes are machine-stable: $toggle',
    );

    // The receipt records requested vs generated vs skipped + codes.
    final receipt =
        jsonDecode(
              await File(
                p.join(workspace.path, '.zfa', 'receipts', 'usecase-Task.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final input = receipt['input'] as Map<String, dynamic>;
    expect(input['requested_methods'], ['get', 'toggle']);
    expect(input['generated_methods'], ['get']);
    expect(input['skipped_methods'], ['toggle']);
    final codes = (input['guard_reason_codes'] as Map).cast<String, String>();
    expect(codes['toggle'], contains('interface_missing_method'));
    expect(codes['toggle'], contains('TaskRepository.toggle'));
  });

  test('missing entity name is a usage error (exit 64), not a crash', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      '--json',
    ]);
    expect(output, contains('Usage'));
    expect(exitCode, 64, reason: 'usage-error family: $output');
  });
}

/// Parses the --json envelope. In --json mode the command prints ONLY the
/// envelope on stdout (machine-readable), so the whole trimmed output must
/// decode.
Map<String, dynamic> _parseEnvelope(String output) {
  final trimmed = output.trim();
  expect(
    trimmed.startsWith('{'),
    isTrue,
    reason: '--json mode must print only the JSON envelope:\n$output',
  );
  return jsonDecode(trimmed) as Map<String, dynamic>;
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

/// Scaffolds a repository interface at the canonical location declaring
/// exactly [methods], mimicking a prior run.
Future<void> _scaffoldRepository(
  String projectRoot,
  String entityName,
  List<String> methods,
) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory(
    p.join(projectRoot, 'lib', 'src', 'domain', 'repositories'),
  );
  await dir.create(recursive: true);
  final signatures = methods
      .map((m) {
        switch (m) {
          case 'get':
            return '  Future<$entityName> get(covariant dynamic params);';
          case 'update':
            return '  Future<$entityName> update(covariant dynamic params);';
          case 'toggle':
            return '  Future<$entityName> toggle(covariant dynamic params);';
          default:
            return '  Future<$entityName> $m(covariant dynamic params);';
        }
      })
      .join('\n');
  await File(
    p.join(dir.path, '${snake}_repository.dart'),
  ).writeAsString('abstract class ${entityName}Repository {\n$signatures\n}\n');
}

String _camelToSnake(String input) => input
    .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
    .replaceFirst(RegExp(r'^_'), '');
