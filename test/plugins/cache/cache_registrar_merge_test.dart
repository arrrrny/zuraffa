import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/cache/capabilities/create_cache_adapter_capability.dart';

/// Issue #1734 — registrar regeneration must:
///   1. Skip *_cache.dart files that have no matching entity (no AdapterSpec,
///      no import for a non-existent file).
///   2. Preserve hand-maintained AdapterSpec entries already in the registrar.
void main() {
  late Directory workspace;
  late String outputDir;
  late CachePlugin plugin;
  late CreateCacheAdapterCapability capability;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('cache_reg_1734_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    plugin = CachePlugin(outputDir: outputDir);
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

  Future<String> registrarContent() =>
      File(p.join(outputDir, 'cache', 'hive_registrar.dart')).readAsString();

  group('issue #1734: non-entity cache files', () {
    test(
      'a *_cache.dart file without a matching entity produces no AdapterSpec',
      () async {
        // Create a cache file for a non-entity (no domain file exists)
        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(
          p.join(cacheDir, 'pending_navigation_cache.dart'),
        ).writeAsString('// generated cache for PendingNavigation\n');

        // Also create a real entity with a cache file
        await writeEntity('Product');
        await capability.execute({'name': 'Product'});

        final content = await registrarContent();

        // The non-entity cache file should NOT produce an AdapterSpec
        expect(content, isNot(contains('AdapterSpec<PendingNavigation>()')));
        // The non-entity import should NOT be present
        expect(
          content,
          isNot(contains('pending_navigation/pending_navigation.dart')),
        );
        // The real entity should still be there
        expect(content, contains('AdapterSpec<Product>()'));
      },
    );

    test(
      'a *_cache.dart file for an enum produces an AdapterSpec with enum import',
      () async {
        // Create an enum file
        final enumsDir = p.join(outputDir, 'domain', 'entities', 'enums');
        await Directory(enumsDir).create(recursive: true);
        await File(
          p.join(enumsDir, 'status.dart'),
        ).writeAsString('enum Status { active, inactive }\n');

        // Create a cache file for the enum
        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(
          p.join(cacheDir, 'status_cache.dart'),
        ).writeAsString('// generated cache for Status\n');

        // Trigger regeneration via a real entity
        await writeEntity('Product');
        await capability.execute({'name': 'Product'});

        final content = await registrarContent();

        // The enum cache file SHOULD produce an AdapterSpec
        expect(content, contains('AdapterSpec<Status>()'));
        // The import should point to the enum file
        expect(content, contains('enums/status.dart'));
      },
    );
  });

  group('issue #1734: merge-preserving regeneration', () {
    test('hand-maintained AdapterSpec entries survive regeneration', () async {
      // Set up a real entity
      await writeEntity('Product');

      // Simulate a hand-maintained registrar with extra adapters
      final cacheDir = p.join(outputDir, 'cache');
      await Directory(cacheDir).create(recursive: true);
      final registrarPath = p.join(cacheDir, 'hive_registrar.dart');
      await File(registrarPath).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';
import '../domain/entities/url_endpoint/url_endpoint.dart';
import '../domain/entities/parser/parser.dart';

part 'hive_registrar.g.dart';

extension HiveRegistrar on HiveInterface {
  @GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<UrlEndpoint>(), AdapterSpec<Parser>()])
  void registerAdapters() {
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(UrlEndpointAdapter());
    Hive.registerAdapter(ParserAdapter());
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(UrlEndpointAdapter());
    Hive.registerAdapter(ParserAdapter());
  }
}
''');

      // Now run cache adapter for Product - should preserve UrlEndpoint and Parser
      await capability.execute({'name': 'Product'});

      final content = await registrarContent();
      expect(content, contains('AdapterSpec<Product>()'));
      expect(
        content,
        contains('AdapterSpec<UrlEndpoint>()'),
        reason: 'hand-maintained adapter must survive regeneration',
      );
      expect(
        content,
        contains('AdapterSpec<Parser>()'),
        reason: 'hand-maintained adapter must survive regeneration',
      );
    });

    test(
      'regeneration does not truncate when cache files cover fewer entities than the existing registrar',
      () async {
        // Set up two entities
        await writeEntity('Product');
        await writeEntity('Category');

        // Simulate a hand-maintained registrar with both
        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(p.join(cacheDir, 'hive_registrar.dart')).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';
import '../domain/entities/category/category.dart';

part 'hive_registrar.g.dart';

extension HiveRegistrar on HiveInterface {
  @GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<Category>()])
  void registerAdapters() {
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(CategoryAdapter());
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(CategoryAdapter());
  }
}
''');

        // Remove the category cache file so only Product's cache file exists
        // (simulating a scenario where the registrar has more adapters than
        // the current cache file set)
        // The hand-maintained Category adapter must survive.

        await capability.execute({'name': 'Product'});

        final content = await registrarContent();
        expect(content, contains('AdapterSpec<Product>()'));
        expect(
          content,
          contains('AdapterSpec<Category>()'),
          reason:
              'hand-maintained Category adapter must survive even without a cache file',
        );
      },
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
