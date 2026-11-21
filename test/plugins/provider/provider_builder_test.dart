import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_provider_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('useZorphy flag for update method in provider', () {
    test('provider emits EntityPatch when useZorphy=true (default)', () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = ProviderPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        service: 'Product',
        domain: 'product',
        methods: ['update'],
        generateData: true,
        useZorphy: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      expect(files.isNotEmpty, isTrue);
      final content = files.first.content ?? '';

      // With useZorphy=true (default), should emit ProductPatch
      expect(
        content.contains('UpdateParams<String, ProductPatch>'),
        isTrue,
        reason: 'useZorphy=true should emit EntityPatch for update params',
      );
      expect(
        content.contains('Partial<Product>'),
        isFalse,
        reason: 'useZorphy=true should NOT emit Partial<Entity>',
      );
    });

    test('provider emits Partial<Entity> when useZorphy=false', () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = ProviderPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        service: 'Product',
        domain: 'product',
        methods: ['update'],
        generateData: true,
        useZorphy: false,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      expect(files.isNotEmpty, isTrue);
      final content = files.first.content ?? '';

      // With useZorphy=false, should emit Partial<Product>
      expect(
        content.contains('UpdateParams<String, Partial<Product>>'),
        isTrue,
        reason: 'useZorphy=false should emit Partial<Entity> for update params',
      );
      // The #942 hide clause names ProductPatch on the barrel import by
      // design — the update path must not USE it, so check the body
      // only, imports excluded.
      final body = content
          .split('\n')
          .where((line) => !line.trim().startsWith('import '))
          .join('\n');
      expect(
        body.contains('ProductPatch'),
        isFalse,
        reason: 'useZorphy=false should NOT emit EntityPatch',
      );
    });
  });

  group('issue #2131 — no-entity provider must not import phantom entities', () {
    test(
      'a no-entity provider with custom params/returns omits the '
      'nonexistent entity imports (regression: zfa build analyzer gate)',
      () async {
        // Issue #2131: `zfa make <Name> --service=... --provider --usecase
        // --di --domain=... --params=... --returns=... --type=stream
        // --no-entity --allow-forward-refs` generated a provider that
        // imported `domain/entities/price_check_params/price_check_params.dart`
        // and `.../price_check_item_result/...` — files that do not exist
        // for a standalone use case (its --params/--returns types carry no
        // backing entity). `zfa build`'s analyzer gate then failed with
        // `uri_does_not_exist` / `undefined_class`. The stream usecase
        // generator already guards its entity imports with
        // `includeMissingEntityFallback: !config.noEntity` (2025 review);
        // the provider builder did not, so it kept emitting the phantom
        // imports.
        final plugin = ProviderPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final config = GeneratorConfig(
          name: 'RunPriceCheckForItem',
          service: 'RunPriceCheckForItemService',
          domain: 'price_check',
          methods: const [],
          paramsType: 'PriceCheckParams',
          returnsType: 'PriceCheckItemResult',
          useCaseType: 'stream',
          noEntity: true,
          generateData: true,
          outputDir: outputDir,
        );

        final files = await plugin.generate(config);
        expect(files, hasLength(1), reason: 'one provider file is emitted');
        final content = files.first.content ?? '';

        // The provider must NOT import the nonexistent entity files.
        expect(
          content,
          isNot(contains('domain/entities/price_check_params')),
          reason: 'no phantom entity import for the custom params type',
        );
        expect(
          content,
          isNot(contains('domain/entities/price_check_item_result')),
          reason: 'no phantom entity import for the custom returns type',
        );
        // The service import (which does exist) is still emitted.
        expect(
          content,
          contains('domain/services/run_price_check_for_item_service.dart'),
          reason: 'the real service import must still be emitted',
        );
      },
    );

    test('an entity-backed provider still imports the entity file '
        '(the #2131 guard must not over-skip)', () async {
      // A normal entity-backed provider (noEntity: false) with an update
      // method MUST keep importing its entity file — the fix is scoped
      // strictly to the no-entity standalone path.
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = ProviderPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final config = GeneratorConfig(
        name: 'Product',
        service: 'Product',
        domain: 'product',
        methods: ['update'],
        generateData: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      expect(files, hasLength(1));
      final content = files.first.content ?? '';

      expect(
        content,
        contains('domain/entities/product/product.dart'),
        reason: 'an entity-backed provider still imports its entity file',
      );
    });

    test('a no-entity provider still imports an entity file that exists '
        '(the #2131 guard must not over-skip in no-entity mode)', () async {
      // CodeRabbit review nitpick on #2134: the guard
      // `includeMissingEntityFallback: !config.noEntity` suppresses ONLY
      // the missing-file fallback branch — the resolver checks the
      // filesystem first (five strategies) and emits a real import when
      // the entity file exists, whatever the fallback flag says. Pin that
      // with a fixture entity present AND noEntity: true, so a regression
      // that suppresses ALL entity imports in no-entity mode is caught.
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = ProviderPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final config = GeneratorConfig(
        name: 'RunPriceCheckForItem',
        service: 'RunPriceCheckForItemService',
        domain: 'price_check',
        methods: const [],
        paramsType: 'Product',
        returnsType: 'PriceCheckItemResult',
        useCaseType: 'stream',
        noEntity: true,
        generateData: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      expect(files, hasLength(1), reason: 'one provider file is emitted');
      final content = files.first.content ?? '';

      expect(
        content,
        contains('domain/entities/product/product.dart'),
        reason:
            'an existing entity file is still imported with noEntity: '
            'true — the guard suppresses only the missing-file fallback',
      );
      expect(
        content,
        isNot(contains('domain/entities/price_check_item_result')),
        reason: 'a genuinely missing entity import stays suppressed',
      );
    });
  });
}

/// Scaffolds a minimal entity file at the canonical v5 location
/// `lib/src/domain/entities/<snake>/<snake>.dart` so that
/// `CommonPatterns.entityImports`' filesystem resolver finds it.
Future<void> _scaffoldEntity(String outputDir, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/entities/$snake');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$snake.dart');
  await file.writeAsString('class $entityName {}\n');
}

String _camelToSnake(String input) {
  final out = input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  return out.startsWith('_') ? out.substring(1) : out;
}
