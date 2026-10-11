@Tags(['e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../helpers/run_zfa_source.dart';

/// Bug #1429 — `zfa entity remove <Name>`: the receipted entity-removal
/// verb, and the Flutter SDK collision warning on `entity create`.
///
/// RED evidence: `zfa entity` had no remove/delete subcommand, and no verb
/// wrote a tombstone for a removed entity — a legitimate spec correction
/// (deleting a mis-declared entity) permanently poisoned the proof
/// preflight with `deleted` findings unless the operator hand-edited
/// `.zfa/receipts/`.
///
/// Driven through a real subprocess ([runZfaSource]): `entity` calls
/// `exit()` on its error paths, and a subprocess keeps the process-global
/// `Directory.current` fully hermetic under parallel `dart test`
/// (the entity_receipt_test.dart #506 pattern).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_bug_1429_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_bug_1429_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
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

  String entityDirPath(String snake) =>
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities', snake);

  Future<List<ReceiptRecord>> receipts() =>
      ReceiptStore(projectRoot: workspace.path).loadAll();

  group('bug 1429 — zfa entity remove', () {
    test('B1: remove deletes the scaffold dir and writes a delete-action '
        'tombstone receipt', () async {
      final create = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Product',
        '--fields',
        'name:String',
      ], workingDirectory: workspace.path);
      expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');
      expect(
        Directory(entityDirPath('product')).existsSync(),
        isTrue,
        reason: 'scaffold must exist before removal',
      );

      final remove = await runZfaSource([
        'entity',
        'remove',
        '-n',
        'Product',
      ], workingDirectory: workspace.path);

      expect(remove.exitCode, 0, reason: 'stdout=${remove.stdout}');
      expect(
        Directory(entityDirPath('product')).existsSync(),
        isFalse,
        reason:
            'the scaffold directory must be deleted: '
            '${remove.stdout}',
      );

      final all = await receipts();
      final tombstones = all
          .where(
            (r) =>
                r.receipt.command == 'entity remove' &&
                r.receipt.entity == 'Product',
          )
          .toList();
      expect(tombstones, hasLength(1), reason: '${remove.stdout}');
      expect(tombstones.single.receipt.capability, 'remove');
      final entry = tombstones.single.receipt.files
          .where(
            (f) => f.path == 'lib/src/domain/entities/product/product.dart',
          )
          .toList();
      expect(entry, hasLength(1));
      expect(entry.single.action, 'delete');
    });

    test(
      'B2: remove after a hand-delete still writes the tombstone '
      '(the recovery path from the issue — no hand-editing the store)',
      () async {
        final create = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Product',
          '--fields',
          'name:String',
        ], workingDirectory: workspace.path);
        expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');
        // The issue's move: delete the scaffold by hand, leaving the
        // entity_create receipt behind (poisoned preflight).
        Directory(entityDirPath('product')).deleteSync(recursive: true);

        final remove = await runZfaSource([
          'entity',
          'remove',
          '-n',
          'Product',
        ], workingDirectory: workspace.path);

        expect(remove.exitCode, 0, reason: 'stdout=${remove.stdout}');
        final all = await receipts();
        expect(
          all.where((r) => r.receipt.command == 'entity remove'),
          hasLength(1),
          reason: 'a tombstone must still be written: ${remove.stdout}',
        );
      },
    );

    test('B3: remove refuses an entity that never existed (no scaffold, no '
        'receipts) with a non-zero exit and the fix line', () async {
      final remove = await runZfaSource([
        'entity',
        'remove',
        '-n',
        'Ghost',
      ], workingDirectory: workspace.path);

      expect(remove.exitCode, isNot(0), reason: '${remove.stdout}');
      expect(remove.stdout, contains('Ghost'));
      expect(remove.stdout, contains('--> fix:'));
    });
  });

  group('bug 1429 — Flutter SDK type collision warning (entity create)', () {
    test('D1: creating an entity named like a Flutter SDK type warns but '
        'still creates (warning, never a refusal)', () async {
      final create = await runZfaSource([
        'entity',
        'create',
        '-n',
        'PlatformException',
        '--fields',
        'code:String',
      ], workingDirectory: workspace.path);

      expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');
      expect(
        create.stdout,
        contains('⚠️'),
        reason: 'the collision warning must be printed: ${create.stdout}',
      );
      expect(create.stdout, contains('PlatformException'));
      expect(
        create.stdout.toLowerCase(),
        contains('flutter'),
        reason: 'the warning must name package:flutter: ${create.stdout}',
      );
      expect(
        File(
          p.join(
            entityDirPath('platform_exception'),
            'platform_exception.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'a warning must not refuse the creation',
      );
    });

    test('D2: a non-colliding name emits no SDK-collision warning (negative '
        'control)', () async {
      final create = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Product',
        '--fields',
        'name:String',
      ], workingDirectory: workspace.path);

      expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');
      expect(
        create.stdout,
        isNot(contains('collides with a Flutter SDK type')),
      );
    });
  });
}
