@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Spec 979, orders 2 + 4 — the make post-pass hook for providers.
///
/// Semantics (stub-first preserved — the hard constraint):
///
///   * FRESH generation: a provider this run just wrote keeps its stub
///     bodies (the TDD flow fills them), but they are not allowed to
///     HIDE — the hook prints the stub notice naming the file, the count,
///     and the fix, records them in the provider receipt, and the run
///     stays green (exit 0);
///   * COMMITTED stubs: a provider the run did NOT rewrite (file existed,
///     action `skipped`) that still contains `UnimplementedError` bodies
///     fails the run — exit 1 + `--> fix:` naming file + method — the
///     stub-escape gate;
///   * CONFORMANCE miss: a provider missing a method its Service
///     interface declares fails the run — exit 1 + `--> fix:` — even on
///     a fresh run (a missing member is a generation defect, not
///     stub-first semantics).
///
/// Runs the real `zfa make` in-process against a temp project (the
/// `runCapturing` pattern from make_command_test.dart).
void main() {
  late Directory workspace;
  late String outputDir;
  late String providerPath;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_provider_postpass_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    providerPath = p.join(
      outputDir,
      'data',
      'providers',
      'product',
      'product_provider.dart',
    );
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_provider_postpass_test
environment:
  sdk: ^3.11.0
''');
    // Entity source (make's entity-exists guard).
    final entityDir = p.join(outputDir, 'domain', 'entities', 'product');
    await Directory(entityDir).create(recursive: true);
    await File(p.join(entityDir, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Workspace already gone.
      }
    }
  });

  /// Hand-writes the `ProductService` interface BEFORE the make run — the
  /// provider mirrors its members (existingMethods extraction) and the
  /// service plugin skips overwriting it (no --force).
  Future<String> writeServiceInterface({
    List<String> methods = const [],
  }) async {
    final services = p.join(outputDir, 'domain', 'services');
    await Directory(services).create(recursive: true);
    final file = p.join(services, 'product_service.dart');
    final members = methods
        .map((m) => '  Future<void> $m(NoParams params);')
        .join('\n');
    await File(file).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

abstract class ProductService {
$members
}
''');
    return file;
  }

  Future<({int code, String output})> runMake() async {
    final runner = CliRunner(exitOnCompletion: false);
    exitCode = 0;
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Product',
      '--service',
      'Product',
    ]);
    final code = exitCode;
    exitCode = 0; // hermetic
    return (code: code, output: output);
  }

  test('fresh generation: stubs are visible (notice + receipt) and the run '
      'stays green — stub-first semantics preserved', () async {
    await writeServiceInterface(methods: ['execute']);

    final result = await runMake();

    expect(
      File(providerPath).existsSync(),
      isTrue,
      reason: 'the provider must have been generated: ${result.output}',
    );
    expect(result.code, equals(0));
    expect(
      result.output,
      contains('stub'),
      reason: 'the hook must NAME the fresh stubs (not allowed to hide)',
    );
    // The stub count rides in the deterministic receipt.
    final receipt = File(
      p.join(workspace.path, '.zfa', 'receipts', 'provider-Product.json'),
    );
    expect(receipt.existsSync(), isTrue);
  });

  test('committed stubs: a provider the run did NOT rewrite fails the run — '
      'exit 1 + fix naming file and method', () async {
    await writeServiceInterface(methods: ['execute']);

    // Run 1: fresh generation (green, stubs recorded).
    final first = await runMake();
    expect(first.code, equals(0));

    // Run 2: the provider file exists and is SKIPPED (no --force) — the
    // committed stubs must now trip the escape gate.
    final second = await runMake();

    expect(second.code, equals(1));
    expect(second.output, contains('UnimplementedError'));
    expect(second.output, contains('product_provider.dart'));
    expect(second.output, contains('execute'));
    expect(second.output, contains('--> fix:'));
  });

  test('filled bodies: after the TDD flow fills the stubs, make is green '
      'again', () async {
    await writeServiceInterface(methods: ['execute']);

    await runMake(); // generate

    // Fill the stub bodies (the TDD flow's job).
    final provider = File(providerPath);
    final filled = provider.readAsStringSync().replaceAll(
      RegExp(
        r'final error = UnimplementedError\([^;]*\);\s*'
        r'final stack = StackTrace\.current;\s*'
        r'logAndHandleError\(error, stack\);\s*'
        r'throw error;',
      ),
      'return;',
    );
    provider.writeAsStringSync(filled);

    final result = await runMake();
    expect(result.code, equals(0));
  });

  test('conformance miss: a provider missing an interface method fails the '
      'run with a fix naming the method', () async {
    await writeServiceInterface(methods: ['execute']);

    await runMake(); // generate provider mirroring `execute`

    // Declare a NEW interface method the provider does not implement.
    final service = File(
      p.join(outputDir, 'domain', 'services', 'product_service.dart'),
    );
    service.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class ProductService {
  Future<void> execute(NoParams params);
  Future<void> rollback(NoParams params);
}
''');

    final result = await runMake();

    expect(
      result.code,
      equals(1),
      reason: 'a missing interface method must fail the make run',
    );
    expect(result.output, contains('rollback'));
    expect(result.output, contains('--> fix:'));
  });
}
