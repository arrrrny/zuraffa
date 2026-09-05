import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/cache/capabilities/create_cache_adapter_capability.dart';

/// Spec #975, Order 4 — dedicated suite for the ~1.5K-LOC cache adapter
/// generator: recursive adapter discovery.
///
/// The discovery/merge semantics are correct (hard constraint: do not
/// change them) — these tests make them PROVEN. The discovered entity set
/// is observable through `execute().data['registeredEntities']` and
/// through the registrar content on disk.
void main() {
  late Directory workspace;
  late String outputDir;
  late CachePlugin plugin;
  late CreateCacheAdapterCapability capability;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('cache_disc_975_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    plugin = CachePlugin(outputDir: outputDir);
    capability = CreateCacheAdapterCapability(plugin);
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> writeEntity(String name, String content) async {
    final snake = _snake(name);
    final dir = p.join(outputDir, 'domain', 'entities', snake);
    await Directory(dir).create(recursive: true);
    await File(p.join(dir, '$snake.dart')).writeAsString(content);
  }

  Future<String> registrarContent() =>
      File(p.join(outputDir, 'cache', 'hive_registrar.dart')).readAsString();

  group('recursive adapter discovery', () {
    test('registers the entity and every transitive sub-entity', () async {
      // Product → Category → Tag: two levels deep.
      await writeEntity('Tag', 'class Tag { final String id; }\n');
      await writeEntity(
        'Category',
        'class Category { final String id; final Tag tag; }\n',
      );
      await writeEntity(
        'Product',
        'class Product { final String id; final Category category; }\n',
      );

      final result = await capability.execute({'name': 'Product'});

      expect(result.success, isTrue, reason: 'result: ${result.message}');
      final registered = (result.data?['registeredEntities'] as List)
          .cast<String>();
      expect(registered, containsAll(['Product', 'Category', 'Tag']));
      expect(registered.first, 'Product', reason: 'the target comes first');

      final content = await registrarContent();
      expect(content, contains('AdapterSpec<Product>()'));
      expect(content, contains('AdapterSpec<Category>()'));
      expect(content, contains('AdapterSpec<Tag>()'));
    });

    test('discovers sub-entities through generic field types', () async {
      await writeEntity('Variant', 'class Variant { final String id; }\n');
      await writeEntity(
        'Product',
        'class Product {\n'
            '  final List<Variant> variants;\n'
            '  final Map<String, Variant>? byId;\n'
            '  final Variant? single;\n'
            '  Product({required this.variants, this.byId, this.single});\n'
            '}\n',
      );

      final result = await capability.execute({'name': 'Product'});

      expect(result.success, isTrue);
      final registered = (result.data?['registeredEntities'] as List)
          .cast<String>();
      expect(registered, contains('Variant'));
      final content = await registrarContent();
      expect(content, contains('AdapterSpec<Variant>()'));
    });

    test('known primitive types are never registered as adapters', () async {
      await writeEntity(
        'Product',
        'class Product {\n'
            '  final String id;\n'
            '  final int count;\n'
            '  final double price;\n'
            '  final bool active;\n'
            '  final DateTime created;\n'
            '}\n',
      );

      final result = await capability.execute({'name': 'Product'});

      expect(result.success, isTrue);
      final registered = (result.data?['registeredEntities'] as List)
          .cast<String>();
      expect(registered, ['Product']);
    });

    test('self-referencing entities terminate (cycle guard)', () async {
      await writeEntity(
        'Node',
        'class Node { final String id; final Node? parent; }\n',
      );

      final result = await capability.execute({'name': 'Node'});

      expect(result.success, isTrue, reason: 'must not loop forever');
      final registered = (result.data?['registeredEntities'] as List)
          .cast<String>();
      expect(registered, ['Node']);
    });
  });

  group('registrar regeneration preserves prior entities', () {
    test('an entity cached before keeps its adapter when another entity is '
        'registered', () async {
      // Prior state: Product already has a cache file and an adapter.
      await writeEntity('Product', 'class Product { final String id; }\n');
      await capability.execute({'name': 'Product'});
      final afterFirst = await registrarContent();
      expect(afterFirst, contains('AdapterSpec<Product>()'));

      // Now register a DIFFERENT entity.
      await writeEntity('Order', 'class Order { final String id; }\n');
      final result = await capability.execute({'name': 'Order'});

      expect(result.success, isTrue);
      final afterSecond = await registrarContent();
      expect(
        afterSecond,
        contains('AdapterSpec<Product>()'),
        reason: 'regeneration must preserve prior cached entities',
      );
      expect(afterSecond, contains('AdapterSpec<Order>()'));
    });

    test('entities with only a cache file (no manual additions entry) are '
        're-registered on regeneration', () async {
      await writeEntity('Product', 'class Product { final String id; }\n');
      // Simulate a pre-existing cache file for an entity never run
      // through `cache adapter` — the registrar regeneration scans
      // *_cache.dart files.
      final cacheDir = p.join(outputDir, 'cache');
      await Directory(cacheDir).create(recursive: true);
      await File(
        p.join(cacheDir, 'legacy_cache.dart'),
      ).writeAsString('// generated cache for Legacy\n');

      await capability.execute({'name': 'Product'});

      final content = await registrarContent();
      expect(
        content,
        contains('AdapterSpec<Legacy>()'),
        reason: 'cache-file entities survive registrar regeneration',
      );
    });
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
