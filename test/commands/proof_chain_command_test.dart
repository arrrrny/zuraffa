import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../helpers/run_zfa_source.dart';

/// Issue #1148 — `zfa proof chain` CLI contract (spec 1334, B4).
///
/// Driven through a real subprocess ([runZfaSource]) so the exit-code
/// protocol (0 intact / 1 drift / 2 infra) is exercised exactly as CI
/// consumes it, and the process-global `Directory.current` that `-C`
/// mutates never races between parallel test files (the
/// `proof_command_test.dart` pattern, issue #506).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_proof_chain_cmd_');
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

  Future<void> seedHealthyReceipt() async {
    final artifact = 'lib/src/domain/entities/product/product.dart';
    final content = 'class Product {}\n';
    final file = File(p.join(workspace.path, artifact));
    await file.create(recursive: true);
    await file.writeAsString(content);
    final bytes = const Utf8Encoder().convert(content);
    await ReceiptStore(projectRoot: workspace.path).save(
      GenerationReceipt(
        command: 'entity create',
        target: 'Product',
        repro: 'zfa entity create Product',
        at: DateTime.utc(2026, 9, 9, 10),
        generatorVersion: '6.2.2',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: artifact,
            action: 'create',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: content,
          ),
        ],
      ),
    );
  }

  group('zfa proof chain', () {
    test('clean project exits 0 with a vacuous-green text verdict', () async {
      final result = await runZfaSource([
        'proof',
        'chain',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('proof-chain'));
      expect(result.stdout, contains('OK'));
    });

    test('--json emits one parseable proof-chain.v1 verdict object', () async {
      await seedHealthyReceipt();

      final result = await runZfaSource([
        'proof',
        'chain',
        '--json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['schema'], 'proof-chain.v1');
      expect(decoded['ok'], isTrue);
      expect(decoded['exitCode'], 0);
      expect(decoded['counts'], isMap);
      expect(decoded['items'], isEmpty);
      expect(decoded['infraErrors'], isEmpty);
    });

    test('a drifted receipt exits 1 with a receipt_digest item carrying '
        'expected/actual digests', () async {
      await seedHealthyReceipt();
      // Hand-edit the receipted artifact after generation.
      await File(
        p.join(workspace.path, 'lib/src/domain/entities/product/product.dart'),
      ).writeAsString('class Product { /* drifted */ }\n');

      final result = await runZfaSource([
        'proof',
        'chain',
        '--json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1, reason: 'stdout=${result.stdout}');
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['ok'], isFalse);
      expect(decoded['exitClass'], 'drift');
      expect(decoded['exitCode'], 1);
      final items = (decoded['items'] as List).cast<Map<String, dynamic>>();
      final digestItem = items.firstWhere(
        (i) => i['category'] == 'receipt_digest',
      );
      expect(digestItem['severity'], 'drift');
      expect(
        digestItem['file'],
        'lib/src/domain/entities/product/product.dart',
      );
      // Expected/actual digests are full SHA-256 hex strings.
      expect((digestItem['expected'] as String), hasLength(64));
      expect((digestItem['actual'] as String), hasLength(64));
      expect(digestItem['fix'], contains('zfa entity create Product'));
    });

    test(
      'text mode prints the drift with expected/actual and a fix line',
      () async {
        await seedHealthyReceipt();
        await File(
          p.join(
            workspace.path,
            'lib/src/domain/entities/product/product.dart',
          ),
        ).writeAsString('class Product { /* drifted */ }\n');

        final result = await runZfaSource([
          'proof',
          'chain',
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 1);
        expect(result.stdout, contains('[drift] receipt_digest'));
        expect(result.stdout, contains('expected:'));
        expect(result.stdout, contains('actual:'));
        expect(result.stdout, contains('--> fix:'));
        expect(result.stdout, contains('FAIL'));
      },
    );

    test('gap-only verdict stays exit 0 (missing links never fail)', () async {
      // A spec behavior with no green evidence is a gap, not an error.
      await Directory(
        p.join(workspace.path, 'specs', 'f1', 'tdd'),
      ).create(recursive: true);
      await File(
        p.join(workspace.path, 'specs', 'f1', 'tdd', 'test-list.md'),
      ).writeAsString(
        '# Test List\n\n## Behaviors\n\n'
        '| # | Behavior | Trace | Test file |\n'
        '|---|----------|-------|-----------|\n'
        '| B1 | does x | FR-1 | test/x_test.dart |\n',
      );

      final result = await runZfaSource([
        'proof',
        'chain',
        '--json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['ok'], isTrue);
      final items = (decoded['items'] as List).cast<Map<String, dynamic>>();
      expect(
        items.any(
          (i) => i['category'] == 'behavior_coverage' && i['severity'] == 'gap',
        ),
        isTrue,
      );
    });

    test('infra error: .zfa/receipts occupied by a file exits 2', () async {
      final receiptsFile = File(p.join(workspace.path, '.zfa', 'receipts'));
      await receiptsFile.create(recursive: true);

      final result = await runZfaSource([
        'proof',
        'chain',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 2, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('infra'));
      expect(result.stdout, contains('--> fix:'));
    });

    test('the #807 proof check surface is untouched (regression)', () async {
      await seedHealthyReceipt();

      final result = await runZfaSource([
        'proof',
        'check',
        '--format=json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['schema'], 'proof.v1');
      expect(decoded['ok'], isTrue);
    });

    test('the proof group help lists both subcommands', () async {
      final result = await runZfaSource([
        'proof',
      ], workingDirectory: workspace.path);

      expect(result.stdout, contains('check'));
      expect(result.stdout, contains('chain'));
    });
  });
}
