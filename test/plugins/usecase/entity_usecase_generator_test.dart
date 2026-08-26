import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_usecase_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('useZorphy flag for update method in entity usecase', () {
    test(
        'entity usecase emits EntityPatch when useZorphy=true (default)',
        () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = UseCasePlugin(
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

    test('entity usecase emits Partial<Entity> when useZorphy=false', () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = UseCasePlugin(
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
      expect(
        content.contains('ProductPatch'),
        isFalse,
        reason: 'useZorphy=false should NOT emit EntityPatch',
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