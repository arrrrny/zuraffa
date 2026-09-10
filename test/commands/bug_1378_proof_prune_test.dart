// Issue #1378 — route-shell / mcp-scaffold receipts record /tmp sandbox
// artifact paths; after the sandbox is garbage-collected the receipts
// report permanent `deleted/missing artifact` findings and NO verb can
// cancel them — a killed background run leaves the proof chain
// permanently red.
//
// Fix under test (spec 1378-proof-prune): `zfa proof prune` — lists
// receipts whose EVERY artifact is missing (dead receipts) and deletes
// them only under `--apply`; partial receipts and live receipts are kept.
//
// Behaviors:
//   B1 — dry run: a dead receipt is listed, nothing is deleted (exit 0).
//   B2 — --apply: the dead receipt file is deleted; a live receipt in
//        the same store survives.
//   B3 — a PARTIAL receipt (some artifacts missing) is kept even under
//        --apply.
//   B4 — no receipts at all → the honest no-receipts message.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/version.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../helpers/run_zfa_source.dart';

GenerationReceiptFile entryFor(String relativePath, String content) {
  final bytes = utf8.encode(content);
  return GenerationReceiptFile(
    path: relativePath,
    action: 'create',
    sha256: crypto.sha256.convert(bytes).toString(),
    bytes: bytes.length,
    snapshot: content,
  );
}

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_proof_prune_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  ReceiptStore store() => ReceiptStore(projectRoot: workspace.path);

  Future<void> seedDeadReceipt() async {
    // The issue's shape: every artifact path points into a TEMP SANDBOX
    // that no longer exists.
    await store().save(
      GenerationReceipt(
        command: 'route shell',
        target: 'App',
        repro: 'zfa route shell Main',
        at: DateTime.utc(2026, 9, 9, 6, 30, 49),
        generatorVersion: version,
        input: const {},
        files: [
          entryFor(
            '../../../../tmp/issue_359_shell_ASCBZU/lib/src/routing/app_shell.dart',
            'dead',
          ),
        ],
      ),
      fileName: 'route-shell-App-2026-09-09T06-30-49.320974Z.json',
    );
  }

  Future<void> seedLiveReceipt() async {
    final artifact = File(
      p.join(workspace.path, 'lib', 'src', 'routing', 'app_shell.dart'),
    );
    await artifact.parent.create(recursive: true);
    await artifact.writeAsString('class AppShell {}\n');
    final bytes = artifact.readAsBytesSync();
    await store().save(
      GenerationReceipt(
        command: 'route shell',
        target: 'AppLive',
        repro: 'zfa route shell Main',
        at: DateTime.utc(2026, 9, 9, 7),
        generatorVersion: version,
        input: const {},
        files: [
          GenerationReceiptFile(
            path: 'lib/src/routing/app_shell.dart',
            action: 'create',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: null,
          ),
        ],
      ),
      fileName: 'route-shell-AppLive.json',
    );
  }

  bool deadReceiptExists() => File(
    p.join(
      store().directory.path,
      'route-shell-App-2026-09-09T06-30-49.320974Z.json',
    ),
  ).existsSync();

  test('B1: dry run lists the dead receipt and deletes nothing', () async {
    await seedDeadReceipt();

    final result = await runZfaSource([
      'proof',
      'prune',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 0, reason: result.stdout);
    expect(result.stdout, contains('route-shell-App-2026-09-09T06-30-49'));
    expect(result.stdout, contains('dry run'));
    expect(deadReceiptExists(), isTrue, reason: 'dry run deletes nothing');
  });

  test('B2: --apply deletes the dead receipt and keeps the live one', () async {
    await seedDeadReceipt();
    await seedLiveReceipt();

    final result = await runZfaSource([
      'proof',
      'prune',
      '--apply',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 0, reason: result.stdout);
    expect(deadReceiptExists(), isFalse, reason: result.stdout);
    expect(
      File(
        p.join(store().directory.path, 'route-shell-AppLive.json'),
      ).existsSync(),
      isTrue,
      reason: 'the live receipt survives',
    );
  });

  test('B3: a partial receipt (some artifacts missing) is kept', () async {
    // One artifact exists on disk, one points into the vanished sandbox.
    final artifact = File(
      p.join(workspace.path, 'lib', 'src', 'domain', 'product.dart'),
    );
    await artifact.parent.create(recursive: true);
    await artifact.writeAsString('class Product {}\n');
    final bytes = artifact.readAsBytesSync();
    await store().save(
      GenerationReceipt(
        command: 'entity create',
        target: 'Product',
        repro: 'zfa entity create Product',
        at: DateTime.utc(2026, 9, 9, 8),
        generatorVersion: version,
        input: const {},
        files: [
          GenerationReceiptFile(
            path: 'lib/src/domain/product.dart',
            action: 'create',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: null,
          ),
          entryFor(
            '../../../../tmp/issue_359_shell_ASCBZU/lib/src/domain/product_dto.dart',
            'dead-half',
          ),
        ],
      ),
      fileName: 'entity-create-Product.json',
    );

    final result = await runZfaSource([
      'proof',
      'prune',
      '--apply',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 0, reason: result.stdout);
    expect(
      File(
        p.join(store().directory.path, 'entity-create-Product.json'),
      ).existsSync(),
      isTrue,
      reason: 'a partial receipt is kept, never pruned',
    );
    expect(result.stdout, contains('partial'), reason: result.stdout);
  });

  test('B4: no receipts at all is an honest no-op', () async {
    final result = await runZfaSource([
      'proof',
      'prune',
      '--apply',
    ], workingDirectory: workspace.path);
    expect(result.exitCode, 0, reason: result.stdout);
    expect(result.stdout, contains('no receipts'));
  });
}
