@Tags(['regression', 'slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_419_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Issue #419: usecase create Future return handling', () {
    test(
      'future usecase with --returns Future<void> is not double-wrapped',
      () async {
        final plugin = UseCasePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );
        final config = GeneratorConfig(
          name: 'EngineLoop',
          service: 'EngineLoopService',
          domain: 'engine',
          paramsType: 'MissionConfig',
          returnsType: 'Future<void>',
          useCaseType: 'future',
          outputDir: outputDir,
          force: true,
        );

        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        expect(
          content.contains('UseCase<void, MissionConfig>'),
          isTrue,
          reason: 'Base class generic should use the inner return type',
        );
        expect(
          content.contains('Future<void> execute'),
          isTrue,
          reason:
              'execute should return Future<void>, not Future<Future<void>>',
        );
        expect(
          content.contains('Future<Future<void>>'),
          isFalse,
          reason: 'Returns type must not be wrapped twice in Future',
        );
        expect(
          content.contains('entities/future/future.dart'),
          isFalse,
          reason: 'Future wrapper must not be treated as an entity import',
        );
      },
    );

    test(
      'future usecase with --returns Future<List<Item>> keeps the inner type',
      () async {
        final plugin = UseCasePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );
        final config = GeneratorConfig(
          name: 'LoadItems',
          service: 'ItemService',
          domain: 'items',
          paramsType: 'NoParams',
          returnsType: 'Future<List<Item>>',
          useCaseType: 'future',
          outputDir: outputDir,
          force: true,
        );

        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        expect(
          content.contains('UseCase<List<Item>, NoParams>'),
          isTrue,
          reason: 'Base class generic should use the inner List<Item> type',
        );
        expect(
          content.contains('Future<List<Item>> execute'),
          isTrue,
          reason:
              'execute should return Future<List<Item>>, not a double Future',
        );
        expect(
          content.contains('Future<Future<List<Item>>>'),
          isFalse,
          reason: 'Returns type must not be wrapped twice in Future',
        );
      },
    );

    test('sync usecase with --returns bool has no async/await', () async {
      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final config = GeneratorConfig(
        name: 'TestSync',
        service: 'MyService',
        domain: 'my_domain',
        paramsType: 'String',
        returnsType: 'bool',
        useCaseType: 'sync',
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      expect(
        content.contains('SyncUseCase<bool, String>'),
        isTrue,
        reason: 'Sync usecase should extend SyncUseCase<bool, String>',
      );
      expect(
        content.contains('bool execute(String params)'),
        isTrue,
        reason: 'Sync execute should return bool directly',
      );
      expect(
        content.contains('async'),
        isFalse,
        reason: 'Sync usecase must not be async',
      );
      expect(
        content.contains('await'),
        isFalse,
        reason: 'Sync usecase must not await',
      );
    });
  });
}
