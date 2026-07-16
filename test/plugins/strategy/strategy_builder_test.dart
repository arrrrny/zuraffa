import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/strategy/builders/strategy_builder.dart';

/// Creates a minimal entity file at the standard Zuraffa entity path.
Future<void> createEntity({
  required String outputDir,
  required String entityName,
  String? domain,
}) async {
  final entitySnake = entityName
      .replaceAllMapped(
        RegExp(r'(?<=[a-z])([A-Z])'),
        (m) => '_${m.group(1)!.toLowerCase()}',
      )
      .toLowerCase();

  final dir = domain != null
      ? Directory('$outputDir/domain/entities/$domain/$entitySnake')
      : Directory('$outputDir/domain/entities/$entitySnake');
  await dir.create(recursive: true);
  await File('${dir.path}/$entitySnake.dart').writeAsString(
    'class $entityName { final String id; '
    '$entityName({required this.id}); '
    'Map<String, dynamic> toJson() => {"id": id}; }',
  );
}

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'zuraffa_strategy_builder_',
    );
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StrategyBuilder.generate()', () {
    test('returns empty list when enableStrategy is false', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: false,
          strategyNames: ['scraper', 'ai'],
        ),
      );
      expect(files, isEmpty);
    });

    test('returns empty list when strategyNames is empty', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: [],
        ),
      );
      expect(files, isEmpty);
    });

    test('generates abstract base, concrete variants, and selector', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
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

      // 1 abstract base + 2 concrete variants + 1 selector = 4
      expect(files, hasLength(4));

      // --- Abstract base ---
      final baseFile = files.firstWhere(
        (f) => f.path.endsWith('url_listing_strategy.dart'),
      );
      expect(baseFile.type, 'strategy_base');
      expect(baseFile.action, anyOf('created', 'overwritten'));

      // --- Concrete variants ---
      final scraperFile = files.firstWhere(
        (f) => f.path.endsWith('scraper_url_listing_strategy.dart'),
      );
      expect(scraperFile.type, 'strategy_variant');
      final aiFile = files.firstWhere(
        (f) => f.path.endsWith('ai_url_listing_strategy.dart'),
      );
      expect(aiFile.type, 'strategy_variant');

      // --- Selector ---
      final selectorFile = files.firstWhere(
        (f) => f.path.endsWith('url_listing_strategy_selector.dart'),
      );
      expect(selectorFile.type, 'strategy_selector');
    });

    test('abstract base has correct content', () async {
      // Create entity files so imports are resolved
      await createEntity(outputDir: outputDir, entityName: 'UrlSpark');
      await createEntity(outputDir: outputDir, entityName: 'Listing');

      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
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

      final baseFile = files.firstWhere(
        (f) => f.path.endsWith('url_listing_strategy.dart'),
      );

      final content = await File(baseFile.path).readAsString();

      expect(content, contains("import 'package:zuraffa/zuraffa.dart';"));
      // Entity imports for paramsType and returnsType
      expect(
        content,
        contains(
          "import '../../../../domain/entities/url_spark/url_spark.dart';",
        ),
      );
      expect(
        content,
        contains("import '../../../../domain/entities/listing/listing.dart';"),
      );
      expect(
        content,
        contains(
          'abstract class UrlListingStrategy extends FetchStrategy<UrlSpark, Listing>',
        ),
      );
    });

    test('concrete variant has correct class name and stubs', () async {
      // Create entity files so imports are resolved
      await createEntity(outputDir: outputDir, entityName: 'UrlSpark');

      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
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

      final scraperFile = files.firstWhere(
        (f) => f.path.endsWith('scraper_url_listing_strategy.dart'),
      );

      final content = await File(scraperFile.path).readAsString();

      // Class declaration
      expect(
        content,
        contains('class ScraperUrlListingStrategy extends UrlListingStrategy'),
      );
      // Has name getter
      expect(
        content,
        contains("String get name => 'ScraperUrlListingStrategy'"),
      );
      // Has canHandle stub
      expect(content, contains('Future<bool> canHandle(UrlSpark input)'));
      expect(content, contains('UnimplementedError'));
      // Has fetchOne stub
      expect(
        content,
        contains(
          'Future<Listing> fetchOne(UrlSpark input, {CancelToken? cancelToken})',
        ),
      );
      // Imports abstract base
      expect(content, contains("import 'url_listing_strategy.dart';"));
      // Entity imports for types that exist on disk
      expect(
        content,
        contains(
          "import '../../../../domain/entities/url_spark/url_spark.dart';",
        ),
      );
    });

    test('entity imports are omitted for known/dynamic types', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'GenericStrategy',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['variant'],
          // paramsType and returnsType not set → defaults to 'dynamic' which is excluded
        ),
      );

      final baseFile = files.firstWhere(
        (f) => f.path.endsWith('generic_strategy_strategy.dart'),
      );
      final content = await File(baseFile.path).readAsString();

      expect(content, contains('abstract class GenericStrategyStrategy'));
      expect(content, contains('extends FetchStrategy<dynamic, dynamic>'));
      // Should NOT have any entity import references
      expect(content, isNot(contains("import '../../")));
    });

    test('entity imports are generated in concrete variant', () async {
      // Create entity files so imports are resolved
      await createEntity(outputDir: outputDir, entityName: 'UrlSpark');
      await createEntity(outputDir: outputDir, entityName: 'Listing');

      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper'],
          paramsType: 'UrlSpark',
          returnsType: 'Listing',
          domain: 'listing',
        ),
      );

      final scraperContent = await File(
        files
            .firstWhere(
              (f) => f.path.endsWith('scraper_url_listing_strategy.dart'),
            )
            .path,
      ).readAsString();

      // Entity imports should appear between package import and relative import
      expect(
        scraperContent,
        contains("import 'package:zuraffa/zuraffa.dart';"),
      );
      expect(
        scraperContent,
        contains(
          "import '../../../../domain/entities/url_spark/url_spark.dart';",
        ),
      );
      expect(
        scraperContent,
        contains("import '../../../../domain/entities/listing/listing.dart';"),
      );
      // Relative import of abstract base should follow entity imports
      expect(scraperContent, contains("import 'url_listing_strategy.dart';"));
    });

    test('entity imports are generated in selector', () async {
      // Create entity files so imports are resolved
      await createEntity(outputDir: outputDir, entityName: 'UrlSpark');
      await createEntity(outputDir: outputDir, entityName: 'Listing');

      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper'],
          paramsType: 'UrlSpark',
          returnsType: 'Listing',
          domain: 'listing',
        ),
      );

      final selectorContent = await File(
        files
            .firstWhere(
              (f) => f.path.endsWith('url_listing_strategy_selector.dart'),
            )
            .path,
      ).readAsString();

      // Entity imports should appear between package import and relative imports
      expect(
        selectorContent,
        contains("import 'package:zuraffa/zuraffa.dart';"),
      );
      expect(
        selectorContent,
        contains(
          "import '../../../../domain/entities/url_spark/url_spark.dart';",
        ),
      );
      expect(
        selectorContent,
        contains("import '../../../../domain/entities/listing/listing.dart';"),
      );
      // Relative imports of strategy files should follow entity imports
      expect(selectorContent, contains("import 'url_listing_strategy.dart';"));
      expect(
        selectorContent,
        contains("import 'scraper_url_listing_strategy.dart';"),
      );
    });

    test('selector wires variants in priority order', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
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

      final selectorFile = files.firstWhere(
        (f) => f.path.endsWith('url_listing_strategy_selector.dart'),
      );

      final content = await File(selectorFile.path).readAsString();

      // Class declaration
      expect(
        content,
        contains(
          'class UrlListingStrategySelector extends StrategySelector<UrlSpark, Listing>',
        ),
      );
      // Constructor params for both variants
      expect(content, contains('required ScraperUrlListingStrategy scraper'));
      expect(content, contains('required AiUrlListingStrategy ai'));
      // Super call with both variants in priority order
      expect(content, contains('super([scraper, ai])'));
      // Imports for both variants
      expect(content, contains("import 'scraper_url_listing_strategy.dart';"));
      expect(content, contains("import 'ai_url_listing_strategy.dart';"));
    });

    test('dry run does not write files to disk', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: true, force: false),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'UrlListing',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper'],
          paramsType: 'UrlSpark',
          returnsType: 'Listing',
          domain: 'listing',
          dryRun: true,
        ),
      );

      expect(files, hasLength(3));
      final basePath =
          '$outputDir/data/providers/listing/strategies'
          '/url_listing_strategy.dart';
      expect(File(basePath).existsSync(), isFalse);
    });

    test('generates files in correct provider/strategies directory', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'BarcodeLookup',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper', 'ai', 'cache'],
          paramsType: 'BarcodeSpark',
          returnsType: 'BarcodeListing',
          domain: 'barcode',
        ),
      );

      // 1 abstract + 3 variants + 1 selector = 5
      expect(files, hasLength(5));

      for (final file in files) {
        expect(
          file.path,
          startsWith('$outputDir/data/providers/barcode/strategies/'),
        );
      }

      // Verify all expected files exist
      expect(
        files.any((f) => f.path.endsWith('barcode_lookup_strategy.dart')),
        isTrue,
      );
      expect(
        files.any(
          (f) => f.path.endsWith('scraper_barcode_lookup_strategy.dart'),
        ),
        isTrue,
      );
      expect(
        files.any((f) => f.path.endsWith('ai_barcode_lookup_strategy.dart')),
        isTrue,
      );
      expect(
        files.any((f) => f.path.endsWith('cache_barcode_lookup_strategy.dart')),
        isTrue,
      );
      expect(
        files.any(
          (f) => f.path.endsWith('barcode_lookup_strategy_selector.dart'),
        ),
        isTrue,
      );
    });

    test('uses dynamic type when params/returns not provided', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'GenericStrategy',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['variant'],
        ),
      );

      final baseFile = files.firstWhere(
        (f) => f.path.endsWith('generic_strategy_strategy.dart'),
      );
      final content = await File(baseFile.path).readAsString();

      expect(content, contains('abstract class GenericStrategyStrategy'));
      expect(content, contains('extends FetchStrategy<dynamic, dynamic>'));
      // No entity imports for dynamic types
      expect(content, isNot(contains("import '../../")));
    });

    test('null domain defaults to name snake_case for folder', () async {
      final builder = StrategyBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(
          name: 'MyDomain',
          outputDir: outputDir,
          enableStrategy: true,
          strategyNames: ['scraper'],
          // domain is null → effectiveDomain returns nameSnake
        ),
      );

      for (final file in files) {
        expect(file.path, contains('/data/providers/my_domain/strategies/'));
      }
    });
  });
}
