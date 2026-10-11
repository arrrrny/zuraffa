@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

/// Issue #1138 (EPIC-1.3, part of #1132 Machine Contract) — receipts on
/// standalone invocations: every capability execute() writes proof.v1.
///
/// The #996 matrix (capability_receipt_test.dart) proved the generic
/// `zfa <plugin> <capability>` path. This suite pins the REMAINING
/// standalone surfaces the issue names:
///
///   * first-party commands that execute capabilities directly, bypassing
///     CapabilityInvocationWrapper (`zfa mock create`, `zfa api <Entity>`);
///   * first-party commands whose bespoke receipts predate the #996
///     provenance schema (`zfa usecase create`, `zfa state create`,
///     `zfa route create`).
///
/// Every row asserts the full machine contract
/// `{plugin, capability, entity, hash, methodset, files, receipt_version: 1}`
/// on the receipt the run leaves in `.zfa/receipts/`.
void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_1138_receipts_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    // `flutter:` under dependencies flips detectProjectFlavor to
    // ProjectFlavor.flutter so the presentation-layer guards (route
    // create) don't skip the run.
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: receipts_1138_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    final entityDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    // toJson() keeps the api-bridge row green (the bridge serializes
    // usecase return types).
    await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});

  Map<String, dynamic> toJson() => {'id': id};
}
''');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  /// The receipt records a run left behind, filtered to [plugin] when
  /// given (the #996 provenance field).
  Future<List<ReceiptRecord>> receipts({String? plugin}) async {
    final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
    return plugin == null
        ? records
        : records.where((r) => r.receipt.plugin == plugin).toList();
  }

  /// The full machine contract every standalone receipt must satisfy
  /// (issue #1138): {plugin, capability, entity, hash, methodset, files,
  /// receipt_version: 1}.
  void expectProofV1Contract(
    ReceiptRecord record, {
    required String label,
    required String plugin,
    required String capability,
    required String entity,
  }) {
    final receipt = record.receipt;
    expect(receipt.plugin, plugin, reason: '`$label` receipt plugin');
    expect(receipt.capability, capability, reason: '`$label` capability');
    expect(receipt.entity, entity, reason: '`$label` entity');
    expect(
      receipt.files,
      isNotEmpty,
      reason: '`$label` receipt must bind the generated files',
    );
    for (final entry in receipt.files) {
      expect(
        File(p.join(workspace.path, entry.path)).existsSync(),
        isTrue,
        reason: '`$label` receipted artifact must exist: ${entry.path}',
      );
    }
    expect(
      receipt.runHash,
      allOf(isNotNull, matches(RegExp(r'^[0-9a-f]{64}$'))),
      reason: '`$label` receipt hash',
    );
    expect(
      receipt.methodset,
      isNotNull,
      reason:
          '`$label` methodset must be present (machine readers must '
          'not guess)',
    );
    expect(receipt.receiptVersion, 1, reason: '`$label` receipt_version');
  }

  group('issue #1138 — standalone invocation receipts', () {
    test('zfa mock create ships the provenance contract', () async {
      final out = await runner.runCapturing([
        '-C',
        workspace.path,
        'mock',
        'create',
        'Product',
      ]);
      expect(
        out,
        isNot(contains('❌ Error')),
        reason: 'mock create must succeed:\n$out',
      );
      final records = await receipts(plugin: 'mock');
      expect(
        records,
        isNotEmpty,
        reason:
            'zfa mock create must persist a receipt carrying '
            'plugin=mock in .zfa/receipts/\nstdout:\n$out',
      );
      expectProofV1Contract(
        records.last,
        label: 'zfa mock create Product',
        plugin: 'mock',
        capability: 'create',
        entity: 'Product',
      );
    });

    test('zfa api <Entity> ships a capability receipt', () async {
      // The api bridge registers the entity's UseCases — seed them with
      // the usecase generator (its own receipt is asserted above).
      final seed = await runner.runCapturing([
        '-C',
        workspace.path,
        'usecase',
        'create',
        'Product',
      ]);
      expect(
        seed,
        isNot(contains('❌')),
        reason: 'usecase seeding must succeed:\n$seed',
      );
      final out = await runner.runCapturing([
        '-C',
        workspace.path,
        'api',
        'Product',
      ]);
      expect(
        out,
        isNot(contains('❌')),
        reason: 'zfa api Product must succeed:\n$out',
      );
      final records = await receipts(plugin: 'api');
      expect(
        records,
        isNotEmpty,
        reason:
            'zfa api Product must persist a receipt in .zfa/receipts/ '
            '(issue #1138)\nstdout:\n$out',
      );
      expectProofV1Contract(
        records.last,
        label: 'zfa api Product',
        plugin: 'api',
        capability: 'create-api-bridge',
        entity: 'Product',
      );
    });

    test('zfa usecase create ships the provenance contract', () async {
      final out = await runner.runCapturing([
        '-C',
        workspace.path,
        'usecase',
        'create',
        'Product',
      ]);
      expect(
        out,
        isNot(contains('❌')),
        reason: 'usecase create must succeed:\n$out',
      );
      final records = await receipts(plugin: 'usecase');
      expect(
        records,
        isNotEmpty,
        reason:
            'zfa usecase create must persist a receipt carrying '
            'plugin=usecase\nstdout:\n$out',
      );
      final record = records.last;
      expectProofV1Contract(
        record,
        label: 'zfa usecase create Product',
        plugin: 'usecase',
        capability: 'create',
        entity: 'Product',
      );
      expect(
        p.basename(record.fileName),
        startsWith('usecase-create-'),
        reason:
            'receipt key must follow the <plugin>-<capability>-<entity> '
            'machine contract (issue #1138)',
      );
    });

    test('zfa state create ships the provenance contract', () async {
      final out = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'create',
        '--name',
        'Product',
      ]);
      expect(
        out,
        isNot(contains('❌')),
        reason: 'state create must succeed:\n$out',
      );
      final records = await receipts(plugin: 'state');
      expect(
        records,
        isNotEmpty,
        reason:
            'zfa state create must persist a receipt carrying '
            'plugin=state\nstdout:\n$out',
      );
      final record = records.last;
      expectProofV1Contract(
        record,
        label: 'zfa state create Product',
        plugin: 'state',
        capability: 'create',
        entity: 'Product',
      );
      expect(
        p.basename(record.fileName),
        startsWith('state-create-'),
        reason:
            'receipt key must follow the <plugin>-<capability>-<entity> '
            'machine contract (issue #1138)',
      );
    });

    test('zfa route create ships the provenance contract', () async {
      final out = await runner.runCapturing([
        '-C',
        workspace.path,
        'route',
        'create',
        'Product',
      ]);
      expect(
        out,
        isNot(contains('❌')),
        reason: 'route create must succeed:\n$out',
      );
      final records = await receipts(plugin: 'route');
      expect(
        records,
        isNotEmpty,
        reason:
            'zfa route create must persist a receipt carrying '
            'plugin=route (issue #1138)\nstdout:\n$out',
      );
      expectProofV1Contract(
        records.last,
        label: 'zfa route create Product',
        plugin: 'route',
        capability: 'create',
        entity: 'Product',
      );
    });
  });
}
