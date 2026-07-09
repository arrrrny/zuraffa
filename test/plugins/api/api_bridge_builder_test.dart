import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/api/builders/api_bridge_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_api_builder_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a minimal UseCase file in the expected location.
  Future<void> _createUseCase({
    required String outputDir,
    required String entitySnake,
    required String className,
    required String content,
  }) async {
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

  /// Creates a minimal entity file.
  Future<void> _createEntity({
    required String outputDir,
    required String entitySnake,
    required String entityName,
  }) async {
    final dir = Directory('$outputDir/domain/entities/$entitySnake');
    await dir.create(recursive: true);
    await File('${dir.path}/$entitySnake.dart').writeAsString(
      'class $entityName { final String id; $entityName({required this.id}); '
      'Map<String, dynamic> toJson() => {"id": id}; }',
    );
  }

  group('ApiBridgeBuilder.generate()', () {
    test('generates file at correct path for Product entity', () async {
      await _createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await _createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      expect(files, hasLength(1));
      expect(files.first.path, endsWith('api/bridges/product_api_bridge.dart'));
      expect(files.first.action, anyOf('created', 'overwritten'));
    });

    test(
      'generated file contains registerProductApiBridge() function',
      () async {
        await _createEntity(
          outputDir: outputDir,
          entitySnake: 'product',
          entityName: 'Product',
        );
        await _createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'GetProductUseCase',
          content:
              'class GetProductUseCase extends UseCase<Product, String> {}',
        );

        final builder = ApiBridgeBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );

        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
        );

        final content = await File(files.first.path).readAsString();
        expect(content, contains('void registerProductApiBridge()'));
        expect(content, contains('_handleGetProduct'));
        expect(content, contains('ZuraffaApiBridge.registerEndpoint'));
        expect(content, contains("ApiEndpoint("));
      },
    );

    test('generated file has kReleaseMode guard as first statement', () async {
      await _createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await _createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      final content = await File(files.first.path).readAsString();
      // kReleaseMode guard must appear inside registerProductApiBridge()
      expect(content, contains('if (kReleaseMode) return;'));
      expect(
        content,
        contains('if (kProfileMode && !Zuraffa.enableApiInProfile) return;'),
      );
    });

    test('generates StreamUseCase handler with streaming response', () async {
      await _createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await _createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'WatchProductUseCase',
        content:
            'class WatchProductUseCase extends StreamUseCase<Product, QueryParams<Product>> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      final content = await File(files.first.path).readAsString();
      expect(content, contains('streaming'));
      expect(content, contains('subscriptionId'));
      expect(content, contains('ZuraffaApiBridge.registerStreamSubscription'));
    });

    test('returns empty list when no UseCases found', () async {
      await _createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      // No UseCase files created
      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(files, isEmpty);
    });

    test(
      'dry run returns file with action but does not write to disk',
      () async {
        await _createEntity(
          outputDir: outputDir,
          entitySnake: 'product',
          entityName: 'Product',
        );
        await _createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'GetProductUseCase',
          content:
              'class GetProductUseCase extends UseCase<Product, String> {}',
        );

        final builder = ApiBridgeBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: true, force: false),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir, dryRun: true),
        );

        expect(files, hasLength(1));
        final outPath = '$outputDir/api/bridges/product_api_bridge.dart';
        expect(File(outPath).existsSync(), isFalse);
      },
    );
  });
}
