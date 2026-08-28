import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_repo_usecase_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('useZorphy flag for update method', () {
    test(
      'repository interface emits EntityPatch when useZorphy=true (default)',
      () async {
        final plugin = RepositoryPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: ['update'],
          generateRepository: true,
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
      },
    );

    test(
      'repository interface emits Partial<Entity> when useZorphy=false',
      () async {
        final plugin = RepositoryPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: ['update'],
          generateRepository: true,
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
          reason:
              'useZorphy=false should emit Partial<Entity> for update params',
        );
        expect(
          content.contains('ProductPatch'),
          isFalse,
          reason: 'useZorphy=false should NOT emit EntityPatch',
        );
      },
    );
  });
}
