import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/strategy/capabilities/create_strategy_capability.dart';
import 'package:zuraffa/src/plugins/strategy/strategy_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_strategy_plugin_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StrategyPlugin', () {
    test('id is "strategy"', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      expect(plugin.id, 'strategy');
    });

    test('name is "Strategy Plugin"', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      expect(plugin.name, 'Strategy Plugin');
    });

    test('version is "1.0.0"', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      expect(plugin.version, '1.0.0');
    });

    test('has one capability: CreateStrategyCapability', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      expect(plugin.capabilities, hasLength(1));
      expect(plugin.capabilities.first, isA<CreateStrategyCapability>());
    });

    test('runAfter is provider', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      expect(plugin.runAfter, ['provider']);
    });

    test('createCommand returns StrategyCommand with name strategy', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      final cmd = plugin.createCommand();
      expect(cmd.name, 'strategy');
    });

    test('generate returns empty list when enableStrategy is false', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final result = await plugin.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(result, isEmpty);
    });

    test('generate returns files for config with strategy enabled', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final result = await plugin.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper', 'ai'],
          paramsType: 'UrlSpark',
          returnsType: 'Listing',
          domain: 'listing',
        ),
      );

      expect(result, hasLength(4));
      expect(result.first.path, contains('url_listing_strategy.dart'));
    });
  });

  group('CreateStrategyCapability', () {
    test('name is "create"', () {
      final plugin = StrategyPlugin(outputDir: outputDir);
      final cap = plugin.capabilities.first as CreateStrategyCapability;
      expect(cap.name, 'create');
    });

    test('execute returns success with generatedFiles key', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final cap = plugin.capabilities.first as CreateStrategyCapability;

      final result = await cap.execute({
        'name': 'UrlListing',
        'strategies': 'scraper,ai',
        'params': 'UrlSpark',
        'returns': 'Listing',
        'domain': 'listing',
        'dryRun': false,
        'force': true,
        'verbose': false,
        'outputDir': outputDir,
      });

      expect(result.success, isTrue);
      expect(result.data?['generatedFiles'], isNotNull);
    });

    test('plan returns EffectReport with correct metadata', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final cap = plugin.capabilities.first as CreateStrategyCapability;

      final report = await cap.plan({
        'name': 'UrlListing',
        'strategies': 'scraper,ai',
        'params': 'UrlSpark',
        'returns': 'Listing',
        'domain': 'listing',
        'outputDir': outputDir,
      });

      expect(report.pluginId, 'strategy');
      expect(report.capabilityName, 'create');
    });

    test('dry run does not write files to disk', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: true, force: false),
      );
      final cap = plugin.capabilities.first as CreateStrategyCapability;

      await cap.execute({
        'name': 'UrlListing',
        'strategies': 'scraper',
        'params': 'UrlSpark',
        'returns': 'Listing',
        'domain': 'listing',
        'dryRun': true,
        'force': false,
        'verbose': false,
        'outputDir': outputDir,
      });

      final outFile = File(
        '$outputDir/data/providers/listing/strategies'
        '/url_listing_strategy.dart',
      );
      expect(outFile.existsSync(), isFalse);
    });

    test('execute with multiple strategies produces all files', () async {
      final plugin = StrategyPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true, verbose: true),
      );
      final cap = plugin.capabilities.first as CreateStrategyCapability;

      final result = await cap.execute({
        'name': 'OrderFetcher',
        'strategies': 'api,cache,fallback',
        'params': 'OrderSpark',
        'returns': 'OrderResult',
        'domain': 'order',
        'dryRun': false,
        'force': true,
        'verbose': false,
        'outputDir': outputDir,
      });

      expect(result.success, isTrue);
      final files = result.data?['generatedFiles'] as List?;
      expect(files, hasLength(5)); // 1 abstract + 3 variants + 1 selector

      final paths = files!.map((f) => f.path as String).toList();
      expect(
        paths.any((p) => p.endsWith('order_fetcher_strategy.dart')),
        isTrue,
      );
      expect(
        paths.any((p) => p.endsWith('api_order_fetcher_strategy.dart')),
        isTrue,
      );
      expect(
        paths.any((p) => p.endsWith('cache_order_fetcher_strategy.dart')),
        isTrue,
      );
      expect(
        paths.any((p) => p.endsWith('fallback_order_fetcher_strategy.dart')),
        isTrue,
      );
      expect(
        paths.any((p) => p.endsWith('order_fetcher_strategy_selector.dart')),
        isTrue,
      );
    });
  });
}
