import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

/// Bug 1972 — `GeneratorConfig.toJson()` never emits a producer for the
/// `generateService` / `useService` bool flags, and it overloads the
/// `'service'` key with the service **name** (a `String?`) that `fromJson()`
/// also reads as a **bool**. After a `toJson()` → `fromJson()` round-trip
/// both flags silently revert to `false`.
///
/// Write side (`toJson()`): `'service': service` — the name only; no
/// `'generate_service'`, no `'use_service'` key.
///
/// Read side (`fromJson()`): `generateService: json['service'] == true ||
/// json['generate_service'] == true` — the name string is never `== true`, so
/// the flag can only come from the dedicated key, which nothing writes;
/// `useService` is not read from any key at all.
///
/// Fix: dedicated `'generate_service'` / `'use_service'` keys on the write
/// side, matching reads on the read side; the `'service'` key keeps carrying
/// the name.
void main() {
  group('bug 1972 — GeneratorConfig service flags round-trip', () {
    test('toJson emits the generate_service and use_service keys', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final json = config.toJson();

      expect(
        json.containsKey('generate_service'),
        isTrue,
        reason:
            "toJson must carry 'generate_service': fromJson reads the flag "
            'from that key, and the overloaded \'service\' key holds the '
            'name (a String?, never == true), so a missing producer '
            'silently clears the flag on replay',
      );
      expect(
        json.containsKey('use_service'),
        isTrue,
        reason:
            "toJson must carry 'use_service': fromJson reads the flag from "
            'that key, so a missing producer silently clears it on replay',
      );
      expect(json['generate_service'], isTrue);
      expect(json['use_service'], isTrue);
    });

    test('generateService: true survives toJson -> fromJson', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.generateService,
        isTrue,
        reason: 'the round-trip must preserve the service-generation flag',
      );
    });

    test('useService: true survives toJson -> fromJson', () {
      final config = GeneratorConfig(
        name: 'Product',
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.useService,
        isTrue,
        reason: 'the round-trip must preserve the use-service flag',
      );
    });

    test('the service name survives the round-trip', () {
      final config = GeneratorConfig(
        name: 'Product',
        service: 'AuthService',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(replayed.service, 'AuthService');
      expect(replayed.effectiveService, 'AuthService');
      expect(replayed.serviceSnake, 'auth_service');
    });

    test('a service name does not flip generateService', () {
      // The overload: the name lives under 'service', the flag used to be
      // read from the same key as a bool. A name is never `== true`, so the
      // flag must come from the dedicated key only.
      final config = GeneratorConfig(
        name: 'Product',
        service: 'AuthService',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(replayed.generateService, isFalse);
      expect(replayed.useService, isFalse);
    });

    test('useService: true keeps hasService and the service name fallback', () {
      final config = GeneratorConfig(
        name: 'Product',
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.hasService,
        isTrue,
        reason: 'hasService keys off useService — the loss was silent here',
      );
      expect(replayed.effectiveService, 'ProductService');
      expect(replayed.serviceSnake, 'product_service');
    });

    test('default (false) flags still round-trip as false', () {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final json = config.toJson();
      expect(json['generate_service'], isFalse);
      expect(json['use_service'], isFalse);

      final replayed = GeneratorConfig.fromJson(json, 'Product');
      expect(replayed.generateService, isFalse);
      expect(replayed.useService, isFalse);
      expect(replayed.hasService, isFalse);
    });

    test('explicit generate_service/use_service external JSON parses true', () {
      final config = GeneratorConfig.fromJson({
        'generate_service': true,
        'use_service': true,
      }, 'Product');

      expect(config.generateService, isTrue);
      expect(config.useService, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // The model is only half the contract: the plugin pipeline carries the
  // flags under its own spellings ('generateService' in di_plugin,
  // 'use-service' / 'useService' in the datasource / di / test / provider /
  // repository plugins), and CodeGenerator mirrors every snake_case key of
  // the config's JSON to its kebab-case spelling. Without those aliases the
  // model and the pipeline would report two different truths for the same
  // flag inside one run.
  // ---------------------------------------------------------------------------

  group('bug 1972 — the service flags reach the generation pipeline', () {
    test('toJson emits the camel aliases the plugins read', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final json = config.toJson();

      expect(
        json['generateService'],
        isTrue,
        reason:
            "di_plugin reads context.data['generateService'] — without "
            "the camel alias the model-level flag is inert downstream",
      );
      expect(
        json['useService'],
        isTrue,
        reason: "the plugins read context.data['useService']",
      );
    });

    test('fromJson reads the alias spellings the pipeline uses', () {
      expect(
        GeneratorConfig.fromJson({
          'generateService': true,
        }, 'Product').generateService,
        isTrue,
      );
      expect(
        GeneratorConfig.fromJson({
          'generate-service': true,
        }, 'Product').generateService,
        isTrue,
        reason:
            "the kebab spelling is what CodeGenerator's options map "
            'mirrors from the snake_case key',
      );
      expect(
        GeneratorConfig.fromJson({'useService': true}, 'Product').useService,
        isTrue,
      );
      expect(
        GeneratorConfig.fromJson({'use-service': true}, 'Product').useService,
        isTrue,
        reason:
            "the kebab spelling is what CodeGenerator's options map "
            'mirrors from the snake_case key',
      );
    });

    test('the CodeGenerator options map carries the flags under every '
        'spelling the plugins read', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final options = CodeGenerator.buildPluginOptions(config.toJson());

      expect(options['use_service'], isTrue);
      expect(
        options['use-service'],
        isTrue,
        reason:
            "the snake->kebab mirror is what puts 'use-service' — the "
            "key four plugins read — into context.data",
      );
      expect(options['useService'], isTrue);
      expect(options['generate_service'], isTrue);
      expect(options['generate-service'], isTrue);
      expect(
        options['generateService'],
        isTrue,
        reason: "di_plugin reads context.data['generateService']",
      );
    });

    test('useService: true now declines the datasource and skips the '
        'repository after the round-trip', () async {
      final outputDir = Directory.systemTemp.createTempSync('bug_1972');
      addTearDown(() => outputDir.deleteSync(recursive: true));

      final replayed = GeneratorConfig.fromJson(
        GeneratorConfig(
          name: 'Product',
          useService: true,
          generateDataSource: true,
          generateRepository: true,
          outputDir: outputDir.path,
        ).toJson(),
        'Product',
      );

      expect(
        replayed.hasService,
        isTrue,
        reason:
            'hasService keys off useService — the datasource declines '
            'and the repository is skipped on this flag',
      );

      final datasource = DataSourcePlugin(
        outputDir: outputDir.path,
        options: const GeneratorOptions(),
      );
      final repository = RepositoryPlugin(
        outputDir: outputDir.path,
        options: const GeneratorOptions(),
      );

      expect(
        await datasource.generate(replayed),
        isEmpty,
        reason: 'a hasService config declines the datasource request',
      );
      expect(
        await repository.generate(replayed),
        isEmpty,
        reason: 'a useService config skips the repository',
      );
    });

    test('useService: true now selects the service and provider plugins in '
        'the generation plan', () {
      final outputDir = Directory.systemTemp.createTempSync('bug_1972_plan');
      addTearDown(() => outputDir.deleteSync(recursive: true));

      final config = GeneratorConfig(
        name: 'Product',
        useService: true,
        outputDir: outputDir.path,
      );
      final generator = CodeGenerator(
        config: config,
        outputDir: outputDir.path,
      );
      final resolver = PlanResolver(
        registry: generator.pluginRegistry,
        config: ZfaConfig.load(projectRoot: generator.projectRoot),
        pluginConfig: PluginConfig.load(projectRoot: generator.projectRoot),
      );

      // The options map CodeGenerator hands to the plan resolver — the
      // mirrored one, which is what `generate()` uses.
      final plan = resolver.resolve(
        name: 'Product',
        options: CodeGenerator.buildPluginOptions(config.toJson()),
      );

      expect(
        plan.pluginIds,
        contains('service'),
        reason:
            "the plan resolver selects 'service' when 'use-service' is "
            'true — the flag reaches the plan, not only the plugins',
      );
      expect(
        plan.pluginIds,
        contains('provider'),
        reason:
            "the plan resolver selects 'provider' when 'use-service' is "
            'true',
      );
    });
  });
}
