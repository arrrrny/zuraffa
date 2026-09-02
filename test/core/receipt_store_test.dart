import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

void main() {
  late Directory workspace;
  late ReceiptStore store;

  GenerationReceipt receipt({
    String command = 'make',
    String target = 'Product',
    String repro = 'zfa make Product',
    DateTime? at,
    List<GenerationReceiptFile>? files,
    GenerationReceiptSpec? spec,
  }) => GenerationReceipt(
    schema: 'proof.v1',
    command: command,
    target: target,
    repro: repro,
    at: at ?? DateTime.utc(2026, 9, 3, 10, 0, 0),
    generatorVersion: '6.1.0',
    input: const {
      'plugin_ids': ['usecase'],
    },
    spec: spec,
    files: files ?? const [],
  );

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_receipt_store_');
    store = ReceiptStore(projectRoot: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('ReceiptStore', () {
    test('save writes a proof.v1 receipt under .zfa/receipts/', () async {
      final file = await store.save(
        receipt(
          files: [
            GenerationReceiptFile(
              path: 'lib/src/domain/entities/product/product.dart',
              action: 'create',
              sha256: 'a' * 64,
              bytes: 42,
            ),
          ],
        ),
      );

      expect(
        p.isWithin(workspace.path, file.path),
        isTrue,
        reason: 'receipt must live inside the project',
      );
      expect(file.existsSync(), isTrue);
      expect(p.split(file.path).contains('.zfa'), isTrue);
      expect(p.split(file.path).contains('receipts'), isTrue);
      expect(p.basename(file.path), endsWith('.json'));

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['schema'], 'proof.v1');
      expect(json['command'], 'make');
      expect(json['target'], 'Product');
      expect(json['generator_version'], '6.1.0');
      expect((json['files'] as List).first['sha256'], 'a' * 64);
    });

    test('loadAll returns receipts sorted by timestamp ascending', () async {
      await store.save(
        receipt(
          command: 'entity create',
          target: 'Alpha',
          at: DateTime.utc(2026, 9, 3, 9, 0, 0),
        ),
      );
      await store.save(
        receipt(target: 'Beta', at: DateTime.utc(2026, 9, 3, 11, 0, 0)),
      );
      await store.save(
        receipt(target: 'Gamma', at: DateTime.utc(2026, 9, 3, 10, 0, 0)),
      );

      final all = await store.loadAll();
      expect(all.map((r) => r.receipt.target).toList(), [
        'Alpha',
        'Gamma',
        'Beta',
      ], reason: 'oldest first so latest-wins indexing can override');
    });

    test('loadAll skips corrupted receipt files instead of throwing', () async {
      await store.save(receipt());
      final dir = Directory(p.join(workspace.path, '.zfa', 'receipts'));
      await File(
        p.join(dir.path, 'broken.json'),
      ).writeAsString('{not json at all');

      final all = await store.loadAll();
      expect(all.length, 1);
    });

    test('loadAll on a project without receipts returns empty list', () async {
      expect(await store.loadAll(), isEmpty);
    });

    test(
      'receipt file name is derived from timestamp, command and target',
      () async {
        final file = await store.save(
          receipt(
            command: 'entity add-field',
            target: 'Order Item',
            at: DateTime.utc(2026, 9, 3, 12, 30, 5, 123),
          ),
        );
        final name = p.basename(file.path);
        expect(name, contains('2026-09-03T12-30-05'));
        expect(name, contains('entity_add-field'));
        // Windows/POSIX safe: no raw colons or spaces survive sanitization.
        expect(name.contains(':'), isFalse);
        expect(name.contains(' '), isFalse);
      },
    );
  });

  group('GenerationReceipt', () {
    test('JSON roundtrip preserves all fields', () {
      final original = receipt(
        spec: GenerationReceiptSpec(
          path: 'lib/src/domain/entities/product/product.dart',
          sha256: 'b' * 64,
          snapshot: 'class Product {}',
        ),
        files: [
          GenerationReceiptFile(
            path: 'lib/src/usecases/get_product.dart',
            action: 'modify',
            sha256: 'c' * 64,
            bytes: 128,
            snapshot: 'final class GetProduct {}',
          ),
          GenerationReceiptFile(
            path: 'lib/src/repositories/product_repository.dart',
            action: 'create',
            sha256: 'd' * 64,
            bytes: 64,
          ),
        ],
      );

      final restored = GenerationReceipt.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.schema, original.schema);
      expect(restored.command, original.command);
      expect(restored.target, original.target);
      expect(restored.repro, original.repro);
      expect(restored.at, original.at);
      expect(restored.generatorVersion, original.generatorVersion);
      expect(restored.input, original.input);
      expect(restored.spec!.path, original.spec!.path);
      expect(restored.spec!.sha256, original.spec!.sha256);
      expect(restored.spec!.snapshot, original.spec!.snapshot);
      expect(restored.files.length, 2);
      expect(restored.files[0].snapshot, original.files[0].snapshot);
      expect(restored.files[1].snapshot, isNull);
    });
  });
}
