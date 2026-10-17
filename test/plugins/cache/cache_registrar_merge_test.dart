import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
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

        // The manual additions entry must carry the resolved enum import —
        // writing the entity-directory path for an enum points at a file
        // that does not exist and the next regeneration retains the broken
        // import.
        final manualAdditions = await File(
          p.join(outputDir, 'cache', 'hive_manual_additions.txt'),
        ).readAsString();
        expect(manualAdditions, contains('enums/status.dart|Status'));
        expect(
          manualAdditions,
          isNot(contains('entities/status/status.dart|Status')),
        );
      },
    );
  });

  group('issue #1734: merge-preserving regeneration', () {
    test('hand-maintained AdapterSpec entries survive regeneration', () async {
      // Set up real entities for every adapter the seeded registrar names —
      // the merge keeps only specs whose entity still resolves.
      await writeEntity('Product');
      await writeEntity('UrlEndpoint');
      await writeEntity('Parser');

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
      // Assert the whole contract for a hand-maintained adapter: the spec,
      // its import, and its registration statement must all survive — a
      // dropped import or registration would still pass a bare
      // AdapterSpec substring check.
      expect(
        content,
        contains("import '../domain/entities/url_endpoint/url_endpoint.dart';"),
        reason: 'hand-maintained adapter import must survive regeneration',
      );
      expect(
        content,
        contains('registerAdapter(UrlEndpointAdapter())'),
        reason:
            'hand-maintained adapter registration must survive regeneration',
      );
      expect(
        content,
        contains('AdapterSpec<UrlEndpoint>()'),
        reason: 'hand-maintained adapter must survive regeneration',
      );
      expect(
        content,
        contains("import '../domain/entities/parser/parser.dart';"),
        reason: 'hand-maintained adapter import must survive regeneration',
      );
      expect(
        content,
        contains('registerAdapter(ParserAdapter())'),
        reason:
            'hand-maintained adapter registration must survive regeneration',
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

        // No *_cache.dart files exist: the registrar is the only source
        // naming Category, so it must survive on the merge path alone.
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

  group('review follow-up: merge validation and preservation (PR #1740)', () {
    test(
      'a non-resolving AdapterSpec already in the registrar is dropped on regeneration',
      () async {
        // The pre-fix generator wrote exactly this artifact: a spec for an
        // entity that no longer exists. Regeneration must heal it — keeping
        // the spec re-crashes hive_ce_generator with the #1734 null check.
        await writeEntity('Product');

        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(p.join(cacheDir, 'hive_registrar.dart')).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';
import '../domain/entities/pending_navigation/pending_navigation.dart';

part 'hive_registrar.g.dart';

extension HiveRegistrar on HiveInterface {
  @GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<PendingNavigation>()])
  void registerAdapters() {
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(PendingNavigationAdapter());
  }
}
''');

        await capability.execute({'name': 'Product'});

        final content = await registrarContent();
        expect(content, contains('AdapterSpec<Product>()'));
        expect(
          content,
          isNot(contains('AdapterSpec<PendingNavigation>()')),
          reason:
              'a spec whose entity no longer resolves must not be re-emitted',
        );
        expect(
          content,
          isNot(contains('pending_navigation/pending_navigation.dart')),
        );
      },
    );

    test(
      'the registrar survives regeneration when no cache files exist and manual additions are comment-only',
      () async {
        await writeEntity('UrlEndpoint');

        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(p.join(cacheDir, 'hive_registrar.dart')).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/url_endpoint/url_endpoint.dart';

part 'hive_registrar.g.dart';

extension HiveRegistrar on HiveInterface {
  @GenerateAdapters([AdapterSpec<UrlEndpoint>()])
  void registerAdapters() {
    Hive.registerAdapter(UrlEndpointAdapter());
  }
}
''');
        // Comment-only manual additions: the old code deleted the registrar
        // on this path before the merge ever ran.
        await File(
          p.join(cacheDir, 'hive_manual_additions.txt'),
        ).writeAsString('# Hive Manual Additions\n# (no entries)\n');

        await plugin.cacheBuilder.regenerateHiveRegistrar(
          GeneratorConfig(
            name: 'UrlEndpoint',
            outputDir: outputDir,
            enableCache: true,
            cacheStorage: 'hive',
          ),
        );

        final registrarFile = File(p.join(cacheDir, 'hive_registrar.dart'));
        expect(await registrarFile.exists(), isTrue);
        final content = await registrarFile.readAsString();
        expect(content, contains('AdapterSpec<UrlEndpoint>()'));
        expect(
          content,
          contains(
            "import '../domain/entities/url_endpoint/url_endpoint.dart';",
          ),
        );
      },
    );

    test(
      'an enum whose name is a prefix of the cache file stem produces no AdapterSpec',
      () async {
        // status_cache.dart + `enum StatusCode` must not emit
        // AdapterSpec<Status>() — the bare substring match re-admitted the
        // #1734 null-check crash class.
        final enumsDir = p.join(outputDir, 'domain', 'entities', 'enums');
        await Directory(enumsDir).create(recursive: true);
        await File(
          p.join(enumsDir, 'status.dart'),
        ).writeAsString('enum StatusCode { ok, err }\n');

        final cacheDir = p.join(outputDir, 'cache');
        await Directory(cacheDir).create(recursive: true);
        await File(
          p.join(cacheDir, 'status_cache.dart'),
        ).writeAsString('// generated cache for a status-like name\n');

        await writeEntity('Product');
        await capability.execute({'name': 'Product'});

        final content = await registrarContent();
        expect(content, isNot(contains('AdapterSpec<Status>()')));
        expect(content, isNot(contains('enums/status.dart')));
        expect(content, contains('AdapterSpec<Product>()'));
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
