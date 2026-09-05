import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../helpers/run_zfa_source.dart';

/// Epic #1011 — TRUTH-FLOOR: regression for issue #996.
///
/// Standalone capability invocations (`zfa <plugin> <capability>
/// <target>`) previously wrote artifacts to disk with ZERO provenance:
/// only the `zfa make` path emitted `proof.v1` receipts (via
/// `PluginManager._persistGenerationReceipt`). The vision's "every
/// artifact ships a verifiable receipt" was therefore partial — and
/// `zfa proof check` had nothing to verify for any artifact a
/// standalone invocation produced.
///
/// The fix in `lib/src/commands/capability_command.dart` mirrors the
/// make-path hook: after a successful capability execution with
/// file-bearing output, the runner writes a `proof.v1` receipt
/// binding every on-disk file to its final SHA-256 digest.
///
/// This test exercises the contract end-to-end via the real CLI
/// subprocess ([runZfaSource]) against the `zfa repository create`
/// standalone capability — one of the 12 capabilities #996 names
/// explicitly (`di create, cache adapter, repository create,
/// usecase create, service create, datasource create, provider
/// create, shadcn <layout>, state create, observer create,
/// sync enable, strategy create`).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp(
      'zfa_capability_receipt_',
    );
    // Minimal project skeleton: pubspec + the entity the repository
    // generator consumes. `zfa repository create --name Product`
    // generates a repository interface, a data-layer implementation,
    // and a datasource — three artifacts that all need receipts.
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_capability_receipt_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
  zuraffa:
    path: ${await _zuraffaPath()}
dev_dependencies:
  build_runner: any
''');

    // The repository generator reads the entity's Zorphy-annotated
    // source to derive its field set; pre-create a minimal entity so
    // the capability succeeds and actually writes files (a zero-file
    // "success" must NOT produce a receipt — that's an empty-proof
    // lie, separately guarded by the #769 contract).
    final entityDir = p.join(
      workspace.path,
      'lib',
      'src',
      'domain',
      'entities',
      'product',
    );
    await Directory(entityDir).create(recursive: true);
    await File(p.join(entityDir, 'product.dart')).writeAsString('''
import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'product.zorphy.dart';
@ZorphyEntity()
class Product {
  @ZorphyField()
  final String id;
  Product({required this.id});
}
''');
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

  Future<List<ReceiptRecord>> receipts() =>
      ReceiptStore(projectRoot: workspace.path).loadAll();

  String digestOf(String relativePath) => crypto.sha256
      .convert(File(p.join(workspace.path, relativePath)).readAsBytesSync())
      .toString();

  group('epic #1011 / issue #996 — standalone capability receipt', () {
    test(
      '`zfa repository create` writes a proof.v1 receipt for every file',
      () async {
        // Run the standalone capability — no `zfa make`, no orchestration
        // layer, just the direct `zfa <plugin> <capability> <target>` form.
        final result = await runZfaSource([
          'repository',
          'create',
          '--name',
          'Product',
        ], workingDirectory: workspace.path);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'precondition: the standalone capability must succeed '
              'before a receipt is warranted. A failing capability that '
              'writes a receipt would be the opposite lie.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stdout,
          contains('✅ Success!'),
          reason: 'precondition: capability reported success.',
        );

        // The truth-floor contract: a receipt must exist after a
        // successful file-bearing standalone capability invocation.
        // Before the fix, `.zfa/receipts/` would be empty (or non-
        // existent) here — the RED state the #996 issue documents.
        final all = await receipts();
        expect(
          all,
          hasLength(1),
          reason:
              'exactly one generation receipt for the standalone '
              'invocation. Pre-fix: zero receipts (the lie). Post-fix: '
              'one receipt per run.',
        );

        final receipt = all.single.receipt;

        // Schema + structure (the #996 deliverable contract).
        expect(receipt.schema, 'proof.v1');
        // The receipt's `command` field names the plugin + capability:
        // `<plugin> <capability>` (e.g. "repository create"), NOT just
        // `make` (which is the zfa-make-path convention).
        expect(receipt.command, 'repository create');
        expect(receipt.target, 'Product');
        expect(receipt.repro, 'zfa repository create Product');
        expect(receipt.generatorVersion, isNotEmpty);
        // The input map records what the capability was invoked with —
        // machine-readable provenance for audit / drift detection.
        expect(receipt.input['name'], 'Product');

        // Every file the capability wrote must be bound to its final
        // on-disk SHA-256. A receipt without per-file digests is a
        // signature with no payload — it cannot prove where anything
        // came from. The `zfa proof check` audit step re-derives each
        // digest and fails on any mismatch (issue #807).
        expect(receipt.files, isNotEmpty);
        expect(
          receipt.files.length,
          greaterThanOrEqualTo(3),
          reason:
              'zfa repository create --name Product generates at '
              'least: a repository interface, a data-layer '
              'implementation, and a datasource. The receipt must '
              'cover all of them.',
        );

        for (final entry in receipt.files) {
          // Each receipt entry's sha256 must match the bytes actually
          // on disk RIGHT NOW (not the bytes the generator claims it
          // wrote). This is the proof-carrying contract.
          expect(
            entry.sha256,
            equals(digestOf(entry.path)),
            reason:
                'receipt digest for ${entry.path} must match the bytes '
                'actually on disk. A mismatch means the artifact was '
                'mutated after the receipt was written (drift) or the '
                'receipt was synthesized without reading the file.',
          );
          // The on-disk file must still exist — a receipt for a
          // missing file is a stale proof.
          expect(
            File(p.join(workspace.path, entry.path)).existsSync(),
            isTrue,
            reason:
                'file ${entry.path} must exist on disk — a receipt '
                'for a missing file is a stale proof.',
          );
          expect(entry.action, 'created');
          expect(entry.bytes, greaterThan(0));
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a zero-file capability "success" must NOT produce an empty receipt',
      () async {
        // The #769 contract: zero files = not a success (exit 1).
        // The #996 receipt hook must respect this — it should NOT
        // write a receipt when no files landed on disk, because an
        // empty receipt looks like proof while certifying nothing.
        // Drive this with --dry-run (no files written) — but the
        // capability still reports "success" internally; the hook
        // must observe zero on-disk files and bail.
        final result = await runZfaSource([
          'repository',
          'create',
          '--name',
          'Product',
          '--dry-run',
        ], workingDirectory: workspace.path);

        // Dry-run is not a failure — it's a preview. But it must NOT
        // produce a receipt (no files landed on disk).
        final all = await receipts();
        expect(
          all,
          isEmpty,
          reason:
              'a dry-run (zero files on disk) must NOT produce a '
              'receipt — an empty receipt would certify "I generated '
              'these 0 files with these 0 digests", which is a lie by '
              'omission. The hook bails on receiptFiles.isEmpty.\n'
              'exit=${result.exitCode}\nstdout=${result.stdout}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Resolve the absolute path to the zuraffa project root so the temp
/// workspace's pubspec can `path:`-depend on it for `dart analyze` /
/// import resolution. Walks up from the test file's CWD until it
/// finds `pubspec.yaml` with `name: zuraffa`.
Future<String> _zuraffaPath() async {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (await pubspec.exists()) {
      final content = await pubspec.readAsString();
      if (content.contains('name: zuraffa')) return dir.path;
    }
    dir = dir.parent;
  }
  // Fall back to the cwd's parent (typical test layout: tests run from
  // the project root, so `Directory.current` IS the zuraffa path).
  return Directory.current.path;
}
