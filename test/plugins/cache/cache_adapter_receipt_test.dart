@Tags(['slow'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../../helpers/run_zfa_source.dart';

/// Spec #975, Order 2 — registrar receipts (proof-carrying generation for
/// `zfa cache adapter`).
///
/// Every `zfa cache adapter <Entity>` run must persist a
/// `.zfa/receipts/*cache-adapter*.json` document binding:
///   * `entity`, `discoveredEntities[]`, `registrarHash`, `buildStatus`
///     (the adapter already computes all of it — it just was never
///     persisted),
///   * the final on-disk registrar bytes (sha256) so `zfa proof check`
///     is GREEN on a fresh run and RED on a hand-edited registrar.
///
/// Driven through a real subprocess ([runZfaSource]) so receipts land in
/// the sandbox's `.zfa/receipts/` (the capability resolves the project
/// root from the actual project, never from the test runner CWD).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_cache_receipt_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_cache_receipt_test
environment:
  sdk: ^3.11.0
''');
    // Entity fixture: Product -> Category (one nested level).
    for (final name in ['product', 'category']) {
      final dir = p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'entities',
        name,
      );
      await Directory(dir).create(recursive: true);
      final pascal = name == 'product' ? 'Product' : 'Category';
      final field = name == 'product'
          ? 'final Category category;'
          : 'final String id;';
      await File(p.join(dir, '$name.dart')).writeAsString('''
class $pascal {
  final String id;
  $field
}
''');
    }
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

  const registrarPath = 'lib/src/cache/hive_registrar.dart';
  const entitySpecPath = 'lib/src/domain/entities/product/product.dart';

  String digestOf(String relativePath) => crypto.sha256
      .convert(File(p.join(workspace.path, relativePath)).readAsBytesSync())
      .toString();

  Future<List<ReceiptRecord>> receipts() =>
      ReceiptStore(projectRoot: workspace.path).loadAll();

  Future<ProcessResult> runAdapter({List<String> extra = const []}) =>
      runZfaSource([
        '-C',
        workspace.path,
        'cache',
        'adapter',
        'Product',
        ...extra,
      ], workingDirectory: workspace.path);

  group('cache adapter writes the registrar receipt (spec #975)', () {
    test('a cache-adapter receipt lands in .zfa/receipts/ with the full '
        'payload', () async {
      final result = await runAdapter();

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout} stderr=${result.stderr}',
      );
      // Order 1 sibling: the run must no longer be SILENT — the registrar
      // file is summarized on stdout (pre-#975 this printed nothing).
      expect(
        result.stdout,
        contains('hive_registrar.dart'),
        reason: 'the CLI summary must name the files it wrote',
      );

      final all = await receipts();
      expect(
        all,
        isNotEmpty,
        reason: 'the adapter run must persist a generation receipt',
      );
      final receipt = all.last.receipt;
      // Canonical `<plugin> <capability>` command format (issue #996);
      // the receipt FILENAME keeps the hyphenated plugin-capability key.
      expect(receipt.command, 'cache adapter');
      expect(receipt.target, 'Product');
      expect(receipt.repro, contains('zfa cache adapter Product'));

      final input = receipt.input;
      expect(input['entity'], 'Product');
      expect(
        (input['discoveredEntities'] as List).cast<String>(),
        containsAll(['Product', 'Category']),
      );
      expect(
        input['registrarHash'],
        digestOf(registrarPath),
        reason: 'registrarHash must be the sha256 of the final bytes',
      );
      expect(
        input,
        contains('buildStatus'),
        reason:
            'buildStatus key is always present (null when --build '
            'was not requested)',
      );

      final covered = receipt.files
          .where((f) => f.path == registrarPath)
          .toList();
      expect(covered, hasLength(1));
      expect(covered.single.sha256, digestOf(registrarPath));
    });

    test('the receipt binds the entity source as its spec', () async {
      await runAdapter();

      final receipt = (await receipts()).last.receipt;
      expect(
        receipt.spec,
        isNotNull,
        reason:
            'adapter receipts must bind the entity source they '
            'discovered FROM',
      );
      expect(receipt.spec!.path, entitySpecPath);
      expect(receipt.spec!.sha256, digestOf(entitySpecPath));
    });

    test('zfa proof check is GREEN on a fresh run, RED on a hand-edited '
        'registrar (acceptance)', () async {
      final fresh = await runAdapter();
      expect(fresh.exitCode, 0, reason: 'stdout=${fresh.stdout}');

      // Fresh run: every receipted digest matches the tree.
      final green = await runZfaSource([
        '-C',
        workspace.path,
        'proof',
        'check',
      ], workingDirectory: workspace.path);
      expect(
        green.exitCode,
        0,
        reason: 'fresh generation must verify: ${green.stdout}',
      );
      expect(green.stdout, contains('OK'));

      // Hand-edit the registrar (the drift the receipt must catch).
      final registrarFile = File(p.join(workspace.path, registrarPath));
      await registrarFile.writeAsString(
        '${await registrarFile.readAsString()}\n// hand edit\n',
      );

      final red = await runZfaSource([
        '-C',
        workspace.path,
        'proof',
        'check',
      ], workingDirectory: workspace.path);
      expect(
        red.exitCode,
        1,
        reason: 'a hand-edited registrar must fail the proof check',
      );
      expect(red.stdout, contains('modified'));
      expect(red.stdout, contains(registrarPath));
    });

    test(
      'a second adapter run supersedes the first receipt (latest wins)',
      () async {
        await runAdapter();
        await runAdapter();

        final all = await receipts();
        expect(
          all.where((r) => r.receipt.command == 'cache adapter').length,
          2,
          reason: 'each run ships its own receipt',
        );

        final latest = ReceiptStore.latestForPath(all, registrarPath);
        expect(latest, isNotNull);
        expect(
          latest!.entry.sha256,
          digestOf(registrarPath),
          reason: 'the newest receipt must bind the CURRENT bytes',
        );

        final green = await runZfaSource([
          '-C',
          workspace.path,
          'proof',
          'check',
        ], workingDirectory: workspace.path);
        expect(green.exitCode, 0, reason: 'stdout=${green.stdout}');
      },
    );

    test('a re-run that updates the registrar is never silent (the #975 '
        'lying-success regression)', () async {
      // Pre-#975, every registrar UPDATE reported action 'modified' — a
      // verb CapabilityCommand's summary does not recognize — so re-runs
      // printed NOTHING and exited 0. The honest verb ('updated') must
      // stay pinned.
      await runAdapter();
      final second = await runAdapter();

      expect(second.exitCode, 0, reason: 'stdout=${second.stdout}');
      expect(
        second.stdout,
        contains('hive_registrar.dart'),
        reason:
            'an update run must summarize what it did — silence is '
            'the lying-success shape',
      );
    });

    test('dry-run writes files nowhere and receipts not at all', () async {
      final result = await runAdapter(extra: ['--dry-run']);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      expect(
        File(p.join(workspace.path, registrarPath)).existsSync(),
        isFalse,
        reason: 'dry-run must not write the registrar',
      );
      expect(
        await receipts(),
        isEmpty,
        reason: 'dry-run must not persist a receipt',
      );
    });
  });
}
