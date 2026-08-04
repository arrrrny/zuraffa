import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/api/api_plugin.dart';
import 'package:zuraffa/src/plugins/api/capabilities/create_api_bridge_capability.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_api_plugin_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createUseCase(
    String entitySnake,
    String className,
    String content,
  ) async {
    final dir = Directory('$outputDir/domain/usecases/$entitySnake');
    await dir.create(recursive: true);
    final snake = className
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .toLowerCase();
    await File('${dir.path}/$snake.dart').writeAsString(content);
  }

  Future<void> createEntity(String entitySnake, String entityName) async {
    final dir = Directory('$outputDir/domain/entities/$entitySnake');
    await dir.create(recursive: true);
    await File('${dir.path}/$entitySnake.dart').writeAsString(
      'class $entityName { final String id; $entityName({required this.id}); '
      'Map<String, dynamic> toJson() => {"id": id}; }',
    );
  }

  group('ApiPlugin', () {
    test('id is "api"', () {
      final plugin = ApiPlugin(outputDir: outputDir);
      expect(plugin.id, 'api');
    });

    test('has one capability: CreateApiBridgeCapability', () {
      final plugin = ApiPlugin(outputDir: outputDir);
      expect(plugin.capabilities, hasLength(1));
      expect(plugin.capabilities.first, isA<CreateApiBridgeCapability>());
    });

    test('createCommand returns ApiCommand', () {
      final plugin = ApiPlugin(outputDir: outputDir);
      final cmd = plugin.createCommand();
      expect(cmd.name, 'api');
    });

    test('generate returns empty list when no usecases directory', () async {
      final plugin = ApiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final result = await plugin.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(result, isEmpty);
    });

    test('generate returns GeneratedFile for entity with UseCase', () async {
      await createEntity('product', 'Product');
      await createUseCase(
        'product',
        'GetProductUseCase',
        'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final plugin = ApiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final result = await plugin.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      expect(result, hasLength(1));
      expect(result.first.path, contains('product_api_bridge.dart'));
    });
  });

  group('CreateApiBridgeCapability', () {
    test('name is "create-api-bridge"', () {
      final plugin = ApiPlugin(outputDir: outputDir);
      final cap = plugin.capabilities.first as CreateApiBridgeCapability;
      expect(cap.name, 'create-api-bridge');
    });

    test('execute returns success with generatedFiles key', () async {
      await createEntity('product', 'Product');
      await createUseCase(
        'product',
        'GetProductUseCase',
        'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final plugin = ApiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final cap = plugin.capabilities.first as CreateApiBridgeCapability;

      final result = await cap.execute({
        'name': 'Product',
        'dryRun': false,
        'force': true,
        'verbose': false,
        'outputDir': outputDir,
      });

      expect(result.success, isTrue);
      expect(result.data?['generatedFiles'], isNotNull);
    });

    test('plan returns EffectReport (dry run)', () async {
      await createEntity('product', 'Product');
      await createUseCase(
        'product',
        'GetProductUseCase',
        'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final plugin = ApiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final cap = plugin.capabilities.first as CreateApiBridgeCapability;

      final report = await cap.plan({
        'name': 'Product',
        'outputDir': outputDir,
      });

      expect(report.pluginId, 'api');
      expect(report.capabilityName, 'create-api-bridge');
    });

    test('--dry-run flag does not write file to disk', () async {
      await createEntity('product', 'Product');
      await createUseCase(
        'product',
        'GetProductUseCase',
        'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final plugin = ApiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: true, force: false),
      );
      final cap = plugin.capabilities.first as CreateApiBridgeCapability;

      await cap.execute({
        'name': 'Product',
        'dryRun': true,
        'force': false,
        'verbose': false,
        'outputDir': outputDir,
      });

      final outFile = File('$outputDir/api/bridges/product_api_bridge.dart');
      expect(outFile.existsSync(), isFalse);
    });
  });
}
