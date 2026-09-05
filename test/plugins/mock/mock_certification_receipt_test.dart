// T003 (issue #970, FR-003 / AC-3 / AC-5): the mock-certification receipt.
//
// RED evidence (pre-fix master): no mock command writes any receipt —
// `.zfa/receipts/` stays empty after `zfa mock create Product`, and
// `zfa proof check` reports 0 receipts ("Nothing to prove yet").
//
// Contract pinned here (remediation): every generation appends the
// mock-certification receipt `.zfa/receipts/mock-<entity>.json` — a
// `proof.v1` GenerationReceipt whose files digest the FINAL on-disk
// bytes, whose `input.certification` records methods implemented vs
// interface + fixture hashes + the certification registry id — so
// `zfa proof check` is green on fresh generation and red on hand-edit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'mock_cli_guard.dart';

import 'package:zuraffa/src/core/proof/proof_checker.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_receipt_970_');
    await _scaffoldProduct(tempDir.path);
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    // The cwd lock: Directory.current is process-wide, so concurrent
    // mock CLI test files would otherwise write into each other's
    // fixtures (issue #970: the mutation baseline runs all these files
    // in ONE `dart test` process).
    return CwdGuard.exclusive(
      () => runner.runCapturing(['-C', tempDir.path, ...args]),
    );
  }

  test(
    'A4: zfa mock create Product writes .zfa/receipts/mock-product.json with '
    'methods-vs-interface, fixture hashes and the registry id',
    () async {
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      final receiptFile = File(
        p.join(tempDir.path, '.zfa', 'receipts', 'mock-product.json'),
      );
      expect(
        receiptFile.existsSync(),
        isTrue,
        reason: 'the mock-certification receipt must exist after create',
      );

      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(receipt['schema'], 'proof.v1');
      expect(receipt['command'], 'zfa mock create Product');
      expect(receipt['target'], 'Product');
      expect(receipt['repro'], 'zfa mock create Product');
      expect(receipt['generator_version'], isA<String>());

      // Every emitted artifact is digest-bound to its FINAL on-disk bytes.
      final files = (receipt['files']! as List).cast<Map<String, dynamic>>();
      final receiptPaths = files.map((f) => f['path'] as String).toSet();
      expect(
        receiptPaths,
        containsAll([
          'lib/src/data/mock/product_mock_data.dart',
          'lib/src/data/datasources/product/product_datasource.dart',
          'lib/src/data/datasources/product/product_mock_datasource.dart',
        ]),
        reason: 'the emitted mock surface is receipted',
      );
      for (final entry in files) {
        final onDisk = File(p.join(tempDir.path, entry['path'] as String));
        expect(onDisk.existsSync(), isTrue);
        expect(
          entry['sha256'],
          crypto.sha256.convert(await onDisk.readAsBytes()).toString(),
          reason: '${entry['path']} must be digest-bound to its bytes',
        );
      }

      // The certification sub-record: methods implemented vs interface,
      // fixture hashes, registry id.
      final cert = receipt['input']!['certification']! as Map<String, dynamic>;
      expect(cert['schema'], 1);
      expect(
        (cert['registry_id']! as String).startsWith('mock-cert:product@'),
        isTrue,
        reason: 'the certification registry id (issue #832 spirit)',
      );
      expect(
        cert['interface'],
        'lib/src/data/datasources/product/product_datasource.dart',
      );
      expect(cert['interface_class'], 'ProductDataSource');
      expect(cert['mock_class'], 'ProductMockDataSource');
      expect((cert['interface_methods']! as List).toSet(), {
        'get',
        'update',
        'toggle',
      });
      expect((cert['implemented_methods']! as List).toSet(), {
        'get',
        'update',
        'toggle',
      });
      expect((cert['missing_methods']! as List), isEmpty);
      expect((cert['invented_methods']! as List), isEmpty);
      expect(cert['conformance'], isTrue);

      final fixtureHashes = (cert['fixture_hashes']! as List)
          .cast<Map<String, dynamic>>();
      expect(
        fixtureHashes.any(
          (h) => h['path'] == 'lib/src/data/mock/product_mock_data.dart',
        ),
        isTrue,
        reason: 'the fixture is hashed into the certification',
      );
      final fixture = fixtureHashes.firstWhere(
        (h) => h['path'] == 'lib/src/data/mock/product_mock_data.dart',
      );
      expect(
        fixture['sha256'],
        crypto.sha256
            .convert(
              await File(
                p.join(
                  tempDir.path,
                  'lib/src',
                  'data',
                  'mock',
                  'product_mock_data.dart',
                ),
              ).readAsBytes(),
            )
            .toString(),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A4b: mock data and mock json generations write their receipts too',
    () async {
      await runCli(['mock', 'data', 'Product']);
      exitCode = exitCodeAtEntry;
      expect(
        File(
          p.join(tempDir.path, '.zfa', 'receipts', 'mock-product.json'),
        ).existsSync(),
        isTrue,
        reason: 'data generation writes the per-entity receipt',
      );

      await runCli(['mock', 'json', 'Product']);
      exitCode = exitCodeAtEntry;
      expect(
        File(
          p.join(tempDir.path, '.zfa', 'receipts', 'mock-product.json'),
        ).existsSync(),
        isTrue,
        reason: 'json generation writes the per-entity receipt',
      );

      // The json run superseded the data run: the receipt reflects the
      // LATEST generation (the checker's latest-wins contract).
      final receipt =
          jsonDecode(
                File(
                  p.join(tempDir.path, '.zfa', 'receipts', 'mock-product.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(receipt['command'], 'zfa mock json Product');
      final cert = receipt['input']!['certification']! as Map<String, dynamic>;
      expect(
        (cert['fixture_hashes']! as List).isNotEmpty,
        isTrue,
        reason: 'the json fixtures are hashed',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'A5: zfa proof check is green on fresh generation and red on hand-edit',
    () async {
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      // Fresh generation: green (in-process checker).
      final fresh = await ProofChecker(projectRoot: tempDir.path).check();
      expect(
        fresh.ok,
        isTrue,
        reason:
            'fresh generation proves every artifact: '
            '${fresh.findings.map((f) => f.detail)}',
      );
      expect(fresh.receipts, greaterThanOrEqualTo(1));

      // Fresh generation: green through the CLI as well.
      final cliOut = await runCli(['proof', 'check']);
      expect(exitCode, 0, reason: 'zfa proof check exits 0:\n$cliOut');
      exitCode = exitCodeAtEntry;

      // Hand-edit a receipted artifact: the digest no longer matches.
      final artifact = File(
        p.join(
          tempDir.path,
          'lib',
          'src',
          'data',
          'datasources',
          'product',
          'product_mock_datasource.dart',
        ),
      );
      await artifact.writeAsString(
        '// hand-edited: drift on purpose\n${await artifact.readAsString()}',
      );

      final drifted = await ProofChecker(projectRoot: tempDir.path).check();
      expect(drifted.ok, isFalse, reason: 'hand-edit must fail the proof');
      expect(
        drifted.findings.any(
          (f) =>
              f.kind == ProofFinding.kindModified &&
              f.path ==
                  'lib/src/data/datasources/product/product_mock_datasource.dart',
        ),
        isTrue,
        reason: 'the finding names the drifted mock artifact',
      );

      // And through the CLI: exit 1.
      final cliOut2 = await runCli(['proof', 'check']);
      expect(
        exitCode,
        1,
        reason: 'zfa proof check exits 1 on drift:\n$cliOut2',
      );
      expect(cliOut2, contains('modified'));
      exitCode = exitCodeAtEntry;
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'A5b: the envelope certification.receipt names the receipt path',
    () async {
      final out = await runCli(['mock', 'create', 'Product', '--json']);
      exitCode = exitCodeAtEntry;
      final envelope = jsonDecode(out) as Map<String, dynamic>;
      final cert = envelope['certification']! as Map<String, dynamic>;
      expect(cert['receipt'], '.zfa/receipts/mock-product.json');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _scaffoldProduct(String root) async {
  final dir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'product'),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});
}
''');
}
