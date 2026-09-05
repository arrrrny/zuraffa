import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';

/// Spec 1003 (T002) — dedicated structural tests for the `cache` trust-tier
/// generator (`test/plugins/cache/`).
///
/// Complements the existing capability-validation test with generator-level
/// assertions: file count, paths, imports, function signatures and the
/// expected Hive stub bodies.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_cache_tier_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  CachePlugin buildPlugin() => CachePlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  test('generates the full Hive cache file set (3 files)', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: outputDir,
      ),
    );

    expect(files, hasLength(3));
    final paths = files.map((f) => f.path).toSet();
    expect(
      paths,
      containsAll(<Matcher>[
        contains('cache/product_cache.dart'),
        contains('cache/daily_cache_policy.dart'),
        contains('cache/timestamp_cache.dart'),
      ]),
    );
  });

  test('emits entity box init with Hive stub body', () async {
    await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: outputDir,
      ),
    );

    final content = File(
      '$outputDir/cache/product_cache.dart',
    ).readAsStringSync();

    expect(content, contains('// GENERATED - DO NOT EDIT'));
    expect(content, contains("import 'package:zuraffa/zuraffa.dart';"));
    expect(
      content,
      contains("import '../domain/entities/product/product.dart';"),
    );
    expect(content, contains('Future<void> initProductCache() async {'));
    expect(content, contains("await Hive.openBox<Product>('products');"));
    expect(content, contains('// END GENERATED'));
  });

  test('emits daily cache policy factory and timestamp box init', () async {
    await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: outputDir,
      ),
    );

    final policy = File(
      '$outputDir/cache/daily_cache_policy.dart',
    ).readAsStringSync();
    expect(policy, contains('CachePolicy createDailyCachePolicy() {'));
    expect(policy, contains('if (Zuraffa.disableCache) {'));
    expect(policy, contains('return DisabledCachePolicy();'));
    expect(policy, contains("Hive.box<int>('cache_timestamps')"));
    expect(policy, contains('return DailyCachePolicy('));

    final timestamp = File(
      '$outputDir/cache/timestamp_cache.dart',
    ).readAsStringSync();
    expect(timestamp, contains('Future<void> initTimestampCache() async {'));
    expect(timestamp, contains("await Hive.openBox<int>('cache_timestamps');"));
  });

  test('non-hive cache storage is a no-op', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        enableCache: true,
        outputDir: outputDir,
      ),
    );

    expect(files, isEmpty);
    expect(Directory('$outputDir/cache').existsSync(), isFalse);
  });
}
