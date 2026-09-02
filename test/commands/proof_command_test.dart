import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../helpers/run_zfa_source.dart';

/// Issue #807 — `zfa proof check` CLI contract.
///
/// Driven through a real subprocess ([runZfaSource]) so the exit-code
/// protocol (0 green / 1 drift) is exercised exactly as CI consumes it,
/// and the process-global `Directory.current` that `-C` mutates never
/// races between parallel test files (issue #506 pattern).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  Future<GenerationReceiptFile> seedGenerated(
    String relativePath,
    String content,
  ) async {
    final file = File(p.join(workspace.path, relativePath));
    await file.create(recursive: true);
    await file.writeAsString(content);
    final bytes = file.readAsBytesSync();
    return GenerationReceiptFile(
      path: relativePath,
      action: 'create',
      sha256: crypto.sha256.convert(bytes).toString(),
      bytes: bytes.length,
      snapshot: content,
    );
  }

  Future<void> seedReceipt(List<GenerationReceiptFile> files) async {
    await ReceiptStore(projectRoot: workspace.path).save(
      GenerationReceipt(
        command: 'entity create',
        target: 'Product',
        repro: 'zfa entity create Product',
        at: DateTime.utc(2026, 9, 3, 10),
        generatorVersion: '6.1.0',
        input: const {},
        files: files,
      ),
    );
  }

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_proof_command_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
  });

  tearDown(() {
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('zfa proof check', () {
    test('prints a green text verdict and exits 0', () async {
      final entry = await seedGenerated(
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await seedReceipt([entry]);

      final result = await runZfaSource([
        'proof',
        'check',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('proof'));
      expect(result.stdout, contains('OK'));
    });

    test('emits a proof.v1 JSON envelope with --format=json', () async {
      final entry = await seedGenerated(
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await seedReceipt([entry]);

      final result = await runZfaSource([
        'proof',
        'check',
        '--format=json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0);
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['schema'], 'proof.v1');
      expect(decoded['ok'], isTrue);
      expect(decoded['receipts'], 1);
      expect(decoded['filesChecked'], 1);
      expect(decoded['findings'], isEmpty);
    });

    test('editing a receipted artifact fails with a diff and exit 1', () async {
      final entry = await seedGenerated(
        'lib/src/domain/entities/product/product.dart',
        'class Product {\n  final String id;\n}\n',
      );
      await seedReceipt([entry]);
      await File(p.join(workspace.path, entry.path)).writeAsString(
        'class Product {\n  final String id;\n  final String name;\n}\n',
      );

      final result = await runZfaSource([
        'proof',
        'check',
        '--format=json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1);
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['ok'], isFalse);
      final findings = (decoded['findings'] as List)
          .cast<Map<String, dynamic>>();
      expect(findings, hasLength(1));
      expect(findings.single['kind'], 'modified');
      expect(findings.single['path'], entry.path);
      expect(findings.single['diff'], contains('+   final String name;'));
    });

    test('text mode surfaces the precise diff for a hand edit', () async {
      final entry = await seedGenerated(
        'lib/src/domain/entities/product/product.dart',
        'class Product {\n  final String id;\n}\n',
      );
      await seedReceipt([entry]);
      await File(p.join(workspace.path, entry.path)).writeAsString(
        'class Product {\n  final String id;\n  final String name;\n}\n',
      );

      final result = await runZfaSource([
        'proof',
        'check',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('modified'));
      expect(result.stdout, contains(entry.path));
      expect(result.stdout, contains('+   final String name;'));
      expect(
        result.stdout,
        contains('zfa entity create Product'),
        reason: 'findings name the repro so the fix is one paste away',
      );
    });

    test('unprovenanced files under audited paths fail the check', () async {
      final entry = await seedGenerated(
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await seedReceipt([entry]);
      File(p.join(workspace.path, 'lib/src/usecases/mystery.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('final class Mystery {}\n');

      final result = await runZfaSource([
        'proof',
        'check',
        'lib/src',
        '--format=json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1);
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['ok'], isFalse);
      final findings = (decoded['findings'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        findings.any(
          (f) =>
              f['kind'] == 'unprovenanced' &&
              f['path'] == 'lib/src/usecases/mystery.dart',
        ),
        isTrue,
      );
    });

    test('a project with no receipts reports a vacuous green', () async {
      final result = await runZfaSource([
        'proof',
        'check',
        '--format=json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0);
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['ok'], isTrue);
      expect(decoded['receipts'], 0);
    });
  });
}
