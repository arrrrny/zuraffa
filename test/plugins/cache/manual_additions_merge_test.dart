import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/cache/capabilities/create_cache_adapter_capability.dart';

/// Spec #975, Order 4 — manual-additions merge idempotency.
///
/// `hive_manual_additions.txt` is the hand-editable merge seam between
/// user intent and registrar generation. Its invariants (hard constraint:
/// do not change the merge semantics — make them proven):
///   * comments and blank lines are preserved verbatim,
///   * existing entries are kept and de-duplicated,
///   * re-running the same registration is idempotent (no duplicate
///     entries, byte-stable content).
void main() {
  late Directory workspace;
  late String outputDir;
  late CreateCacheAdapterCapability capability;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('cache_merge_975_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    final plugin = CachePlugin(outputDir: outputDir);
    capability = CreateCacheAdapterCapability(plugin);
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> writeEntity(String name) async {
    final snake = _snake(name);
    final dir = p.join(outputDir, 'domain', 'entities', snake);
    await Directory(dir).create(recursive: true);
    await File(
      p.join(dir, '$snake.dart'),
    ).writeAsString('class $name { final String id; }\n');
  }

  Future<File> manualAdditions() =>
      File(
        p.join(outputDir, 'cache', 'hive_manual_additions.txt'),
      ).readAsString().then(
        (_) => File(p.join(outputDir, 'cache', 'hive_manual_additions.txt')),
      );

  test('preserves hand-written comments through a merge', () async {
    await writeEntity('Product');
    final cacheDir = p.join(outputDir, 'cache');
    await Directory(cacheDir).create(recursive: true);
    await File(p.join(cacheDir, 'hive_manual_additions.txt')).writeAsString('''
# Hive Manual Additions
# Add nested entities and enums that need Hive adapters
# Format: import_path|EntityName

# Team note: keep ParserType registered for the parser cache.
../domain/entities/enums/index.dart|ParserType
''');

    await capability.execute({'name': 'Product'});

    final content = await manualAdditions().then((f) => f.readAsString());
    expect(content, contains('# Team note: keep ParserType registered'));
    expect(
      content,
      contains('enums/index.dart|ParserType'),
      reason: 'hand-added entries survive the merge',
    );
    expect(content, contains('product/product.dart|Product'));
  });

  test('running the same registration twice is idempotent (dedup)', () async {
    await writeEntity('Product');

    await capability.execute({'name': 'Product'});
    final first = await manualAdditions().then((f) => f.readAsString());

    await capability.execute({'name': 'Product'});
    final second = await manualAdditions().then((f) => f.readAsString());

    expect(
      'product/product.dart|Product'.allMatches(second).length,
      1,
      reason: 'no duplicate entries after a second run',
    );
    // First-run content minus the single expected entry must be stable:
    // same header, same entry set, byte-identical output.
    expect(
      second,
      first,
      reason: 'a no-new-information rerun must be byte-stable',
    );
  });

  test(
    'a hand-added entity is not duplicated by a later adapter run',
    () async {
      await writeEntity('Category');
      final cacheDir = p.join(outputDir, 'cache');
      await Directory(cacheDir).create(recursive: true);
      final manualPath = p.join(cacheDir, 'hive_manual_additions.txt');
      await File(
        manualPath,
      ).writeAsString('../domain/entities/category/category.dart|Category\n');

      await capability.execute({'name': 'Category'});

      final content = await File(manualPath).readAsString();
      expect(
        'category/category.dart|Category'.allMatches(content).length,
        1,
        reason: 'the merge must dedup against existing entries',
      );
    },
  );

  test('new entities append after existing entries, order preserved', () async {
    await writeEntity('Product');
    await writeEntity('Order');

    await capability.execute({'name': 'Product'});
    await capability.execute({'name': 'Order'});

    final content = await File(
      p.join(outputDir, 'cache', 'hive_manual_additions.txt'),
    ).readAsString();
    final productIdx = content.indexOf('product/product.dart|Product');
    final orderIdx = content.indexOf('order/order.dart|Order');
    expect(productIdx, greaterThan(-1));
    expect(orderIdx, greaterThan(-1));
    expect(
      orderIdx,
      greaterThan(productIdx),
      reason: 'later registrations append, they do not reorder',
    );
  });
}

String _snake(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    if (c.toUpperCase() == c &&
        c.toLowerCase() != c &&
        i > 0 &&
        name[i - 1].toLowerCase() != name[i - 1].toUpperCase()) {
      buffer.write('_');
    }
    buffer.write(c.toLowerCase());
  }
  return buffer.toString();
}
