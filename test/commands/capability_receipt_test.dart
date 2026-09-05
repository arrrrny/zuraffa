@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

/// Spec 0996 (issue #996), FR-002 — every standalone capability
/// invocation emits a receipt into `.zfa/receipts/`.
///
/// The full matrix from the issue, driven through the real CLI surface
/// (in-process CliRunner + `-C <workspace>`, the issue #506 hermetic
/// pattern): for each invocation the receipt file must appear on disk
/// and carry the machine-readable schema
/// `{plugin, capability, entity, hash, methodset, files, receipt_version}`.
///
/// Slow tier: each case boots the plugin registry once (shared runner)
/// and performs a real generation into a temp workspace.
void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_996_matrix_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: matrix_fixture
environment:
  sdk: ^3.11.0
''');
    // `zfa cache adapter <Entity>` discovers real entity sources under
    // lib/src/domain/entities — seed one (the make-receipt fixture
    // pattern).
    final entityDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
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

  Future<ReceiptRecord?> latestCapabilityReceipt(String plugin) async {
    final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
    final matches = records.where((r) => r.receipt.plugin == plugin).toList();
    return matches.isEmpty ? null : matches.last;
  }

  /// One matrix row: the CLI invocation + the receipt expectations.
  Future<void> expectReceipt({
    required String label,
    required List<String> args,
    required String plugin,
    required String capability,
    required String entity,
  }) async {
    final out = await runner.runCapturing(['-C', workspace.path, ...args]);
    expect(
      out,
      isNot(contains('❌')),
      reason: '`$label` must succeed for the receipt to be meaningful:\n$out',
    );
    final record = await latestCapabilityReceipt(plugin);
    expect(
      record,
      isNotNull,
      reason:
          '`$label` must persist a receipt in .zfa/receipts/ '
          '(issue #996)\nstdout:\n$out',
    );
    final receipt = record!.receipt;
    expect(receipt.plugin, plugin, reason: '`$label` receipt plugin');
    expect(
      receipt.capability,
      capability,
      reason:
          '`$label` receipt '
          'capability',
    );
    expect(receipt.entity, entity, reason: '`$label` receipt entity');
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
    expect(receipt.receiptVersion, 1, reason: '`$label` receipt_version');
    expect(
      receipt.methodset,
      isNotNull,
      reason:
          '`$label` methodset must be present (machine readers must '
          'not guess)',
    );
    expect(
      p.basename(record.fileName),
      startsWith('$plugin-$capability-'),
      reason:
          '`$label` receipt key must follow '
          '<plugin>-<capability>-<entity>-<timestamp>.json',
    );
  }

  group('spec 0996 — standalone capability receipt matrix', () {
    // B-001: the issue's list, one row per capability. Each invocation
    // runs in its own entity name to keep receipt targets distinct.
    test('di create Product', () async {
      await expectReceipt(
        label: 'zfa di create Product',
        args: ['di', 'create', 'Product'],
        plugin: 'di',
        capability: 'create',
        entity: 'Product',
      );
    });

    test('usecase create Order', () async {
      await expectReceipt(
        label: 'zfa usecase create Order',
        args: ['usecase', 'create', 'Order'],
        plugin: 'usecase',
        capability: 'create',
        entity: 'Order',
      );
    });

    test('repository create Cart', () async {
      await expectReceipt(
        label: 'zfa repository create Cart',
        args: ['repository', 'create', 'Cart'],
        plugin: 'repository',
        capability: 'create',
        entity: 'Cart',
      );
    });

    test('service create Invoice', () async {
      await expectReceipt(
        label: 'zfa service create Invoice',
        args: ['service', 'create', 'Invoice'],
        plugin: 'service',
        capability: 'create',
        entity: 'Invoice',
      );
    });

    test('datasource create Stock', () async {
      await expectReceipt(
        label: 'zfa datasource create Stock',
        args: ['datasource', 'create', 'Stock'],
        plugin: 'datasource',
        capability: 'create',
        entity: 'Stock',
      );
    });

    test('provider create Audit', () async {
      // A provider implements a service interface — the domain demands
      // the service exists first (the CLI says so verbatim).
      await runner.runCapturing([
        '-C',
        workspace.path,
        'service',
        'create',
        'Audit',
      ]);
      await expectReceipt(
        label: 'zfa provider create Audit',
        args: ['provider', 'create', 'Audit'],
        plugin: 'provider',
        capability: 'create',
        entity: 'Audit',
      );
    });

    test('cache adapter Product', () async {
      await expectReceipt(
        label: 'zfa cache adapter Product',
        args: ['cache', 'adapter', 'Product'],
        plugin: 'cache',
        capability: 'adapter',
        entity: 'Product',
      );
    });

    test('state create Counter', () async {
      await expectReceipt(
        label: 'zfa state create Counter',
        args: ['state', 'create', 'Counter'],
        plugin: 'state',
        capability: 'create',
        entity: 'Counter',
      );
    });

    test('observer create Watcher', () async {
      await expectReceipt(
        label: 'zfa observer create Watcher',
        args: ['observer', 'create', 'Watcher'],
        plugin: 'observer',
        capability: 'create',
        entity: 'Watcher',
      );
    });

    test('sync enable Session', () async {
      await expectReceipt(
        label: 'zfa sync enable Session',
        args: ['sync', 'enable', 'Session'],
        plugin: 'sync',
        capability: 'enable',
        entity: 'Session',
      );
    });

    test('strategy create Scraper', () async {
      await expectReceipt(
        label: 'zfa strategy create Scraper scraper,ai',
        args: ['strategy', 'create', 'Scraper', '--strategies', 'scraper,ai'],
        plugin: 'strategy',
        capability: 'create',
        entity: 'Scraper',
      );
    });

    test('shadcn <layout> Product (list layout)', () async {
      // Shadcn widgets are Flutter widgets (Constitution VII, issue
      // #512): the generator skips pure-Dart targets with a warning, so
      // the fixture workspace must declare the flutter SDK.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: matrix_fixture
environment:
  sdk: ^3.11.0
  flutter: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
''');
      await expectReceipt(
        label: 'zfa shadcn list Product',
        args: ['shadcn', 'list', 'Product'],
        plugin: 'shadcn',
        capability: 'list',
        entity: 'Product',
      );
    });
  });
}
