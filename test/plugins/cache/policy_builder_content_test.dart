import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/builders/cache_builder.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Spec #975, Order 4 — policy builder content.
///
/// The cache policy builder emits one `<name>_cache_policy.dart` file per
/// configured policy; these tests pin the generated CONTENT (class, method
/// name, ttl wiring, disableCache guard) so refactors cannot silently
/// change what lands on disk.
void main() {
  late Directory workspace;
  late String outputDir;
  late CacheBuilder builder;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('cache_policy_975_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    builder = CacheBuilder(outputDir: outputDir);
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<String> readCache(String name) =>
      File(p.join(outputDir, 'cache', name)).readAsString();

  test('daily policy: file, factory method and class name', () async {
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        enableCache: true,
        cachePolicy: 'daily',
        cacheStorage: 'hive',
      ),
    );

    final content = await readCache('daily_cache_policy.dart');
    expect(content, contains('createDailyCachePolicy'));
    expect(content, contains('DailyCachePolicy'));
    expect(
      content,
      contains('CachePolicy'),
      reason: 'the factory must return the CachePolicy interface',
    );
  });

  test('daily policy honors the disableCache kill switch', () async {
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        enableCache: true,
        cachePolicy: 'daily',
        cacheStorage: 'hive',
      ),
    );

    final content = await readCache('daily_cache_policy.dart');
    expect(
      content,
      contains('Zuraffa.disableCache'),
      reason: 'policy must early-return a DisabledCachePolicy',
    );
    expect(content, contains('DisabledCachePolicy'));
  });

  test('restart policy: app_restart file and class', () async {
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        enableCache: true,
        cachePolicy: 'restart',
        cacheStorage: 'hive',
      ),
    );

    final content = await readCache('app_restart_cache_policy.dart');
    expect(content, contains('createAppRestartCachePolicy'));
    expect(content, contains('AppRestartCachePolicy'));
  });

  test(
    'ttl policy: minutes are baked into file, method and Duration',
    () async {
      await builder.generate(
        GeneratorConfig(
          name: 'Product',
          outputDir: outputDir,
          enableCache: true,
          cachePolicy: 'ttl',
          cacheStorage: 'hive',
          ttlMinutes: 30,
        ),
      );

      final content = await readCache('ttl_30_minutes_cache_policy.dart');
      expect(content, contains('createTtl30MinutesCachePolicy'));
      expect(content, contains('TtlCachePolicy'));
      expect(
        content,
        contains('Duration(minutes: 30)'),
        reason: 'the TTL must be a compile-time constant duration',
      );
      expect(content, contains('minutes: 30'));
    },
  );

  test('ttl defaults to 1440 minutes when unset', () async {
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        enableCache: true,
        cachePolicy: 'ttl',
        cacheStorage: 'hive',
      ),
    );

    final file = File(
      p.join(outputDir, 'cache', 'ttl_1440_minutes_cache_policy.dart'),
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'unset ttl falls back to the documented 1440 default',
    );
    final content = await file.readAsString();
    expect(content, contains('createTtl1440MinutesCachePolicy'));
  });

  test('policies bind the shared timestamp box', () async {
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        enableCache: true,
        cachePolicy: 'daily',
        cacheStorage: 'hive',
      ),
    );

    final content = await readCache('daily_cache_policy.dart');
    expect(
      content,
      contains("Hive.box<int>('cache_timestamps')"),
      reason: 'policies share the cache_timestamps box',
    );
    expect(content, contains('getTimestamps'));
    expect(content, contains('setTimestamp'));
  });
}
