// Spec 1098 — Engine receipt featureId grouping tests.
//
// Gap 4: engine receipts are entity-centric — engine_receipt_writer.dart
// keys on `target: entityName`; no feature grouping, so "what did feature X
// generate?" is unanswerable. The receipt gains a `feature.id` field and a
// per-feature grouped copy under `.zfa/receipts/<featureId>/`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_receipt_writer.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_receipt_feature_');
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

  Future<File> writeReceipt({String? featureId}) {
    final writer = EngineReceiptWriter(projectRoot: workspace.path);
    return writer.write(
      command: 'zfa make engine Login',
      entityName: 'Login',
      methods: const ['get', 'update'],
      mockCertified: const {'get': true, 'update': false},
      diFiles: const ['lib/src/di/login_di.dart'],
      getItTypes: const ['LoginRepository'],
      engineCheckPassed: true,
      engineCheckFailures: const [],
      generatedFiles: const ['lib/src/domain/entities/login/login.dart'],
      featureId: featureId,
    );
  }

  group('receipt.featureId (gap 4)', () {
    test(
      'without a featureId the receipt is unchanged (no feature key)',
      () async {
        final file = await writeReceipt();
        final receipt =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        expect(receipt['target'], 'Login');
        expect(
          receipt.containsKey('feature'),
          isFalse,
          reason: 'featureless runs must keep the engine.v1 shape',
        );
      },
    );

    test('with a featureId the receipt records feature.id', () async {
      final file = await writeReceipt(featureId: 'login');
      final receipt =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect((receipt['feature'] as Map)['id'], 'login');
      expect(
        receipt['target'],
        'Login',
        reason: 'entity centricity is preserved — feature is additive',
      );
    });

    test(
      'with a featureId a grouped copy lands under .zfa/receipts/<id>/',
      () async {
        await writeReceipt(featureId: 'login');

        final grouped = File(
          p.join(
            workspace.path,
            '.zfa',
            'receipts',
            'login',
            'engine.receipt.json',
          ),
        );
        expect(grouped.existsSync(), isTrue);
        final receipt =
            jsonDecode(grouped.readAsStringSync()) as Map<String, dynamic>;
        expect((receipt['feature'] as Map)['id'], 'login');
        expect(receipt['target'], 'Login');
      },
    );

    test('loadForFeature answers "what did feature X generate?"', () async {
      await writeReceipt(featureId: 'login');
      await writeReceipt(featureId: 'login');
      await writeReceipt(featureId: 'checkout');

      final loginReceipts = EngineReceiptWriter.loadForFeature(
        workspace.path,
        'login',
      );

      expect(loginReceipts, hasLength(2));
      for (final receipt in loginReceipts) {
        expect((receipt['feature'] as Map)['id'], 'login');
      }

      final checkoutReceipts = EngineReceiptWriter.loadForFeature(
        workspace.path,
        'checkout',
      );
      expect(checkoutReceipts, hasLength(1));
    });

    test(
      'groupByFeature partitions every grouped receipt by feature',
      () async {
        await writeReceipt(featureId: 'login');
        await writeReceipt(featureId: 'checkout');

        final grouped = EngineReceiptWriter.groupByFeature(workspace.path);

        expect(grouped.keys, containsAll(['login', 'checkout']));
        expect(grouped['login'], hasLength(1));
        expect(grouped['checkout'], hasLength(1));
      },
    );

    test('groupByFeature on a project without grouped receipts is empty', () {
      expect(EngineReceiptWriter.groupByFeature(workspace.path), isEmpty);
    });

    test('loadForFeature with no such feature is empty (no throw)', () {
      expect(
        EngineReceiptWriter.loadForFeature(workspace.path, 'nope'),
        isEmpty,
      );
    });
  });
}
