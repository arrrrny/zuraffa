import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_json_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_json_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MockJsonBuilder path computation', () {
    test('jsonFilePathFor returns correct path', () {
      final builder = MockJsonBuilder(outputDir: outputDir);
      final path = builder.jsonFilePathFor('Product', 'catalog');
      expect(path, contains('data/mock_json/catalog/product.mock.json'));
    });

    test('helperFilePathFor returns correct path', () {
      final builder = MockJsonBuilder(outputDir: outputDir);
      final path = builder.helperFilePathFor('Product', 'catalog');
      expect(path, contains('data/mock_json/catalog/product_mock_json.dart'));
    });

    test('metaFilePathFor returns correct path', () {
      final builder = MockJsonBuilder(outputDir: outputDir);
      final path = builder.metaFilePathFor('Product', 'catalog');
      expect(path, contains('data/mock_json/catalog/product.mock.json.meta'));
    });

    test('domainForEntity auto-detects from entity location', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; const Product({required this.id}); }',
      );

      final builder = MockJsonBuilder(outputDir: outputDir);
      final domain = builder.domainForEntity('Product');
      expect(domain, 'catalog');
    });

    test('domainForEntity with explicit domain overrides auto-detect', () {
      final builder = MockJsonBuilder(outputDir: outputDir);
      final domain = builder.domainForEntity(
        'Product',
        explicitDomain: 'custom',
      );
      expect(domain, 'custom');
    });

    test('domainForEntity falls back to snake case when not found', () {
      final builder = MockJsonBuilder(outputDir: outputDir);
      final domain = builder.domainForEntity('NonExistent');
      expect(domain, 'non_existent');
    });
  });

  group('MockJsonBuilder JSON generation', () {
    test('generates valid JSON for simple entity', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; final double price; const Product({required this.id, required this.name, required this.price}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final config = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      );

      final files = await builder.generate(config);

      expect(files.isNotEmpty, true);

      final jsonFile = files.firstWhere(
        (f) => f.type == 'mock_json' && f.action != 'skipped',
        orElse: () => throw StateError('No mock_json file found'),
      );

      final jsonPath = jsonFile.path;
      final jsonContent = File(jsonPath).readAsStringSync();

      expect(jsonContent.contains('['), true);
      expect(jsonContent.contains(']'), true);
      expect(jsonContent.contains('"id"'), true);
      expect(jsonContent.contains('"name"'), true);
      expect(jsonContent.contains('"price"'), true);
      expect(jsonContent.contains('name 1'), true);

      final metaFile =
          files
              .where((f) => f.type == 'mock_json' && f.action != 'skipped')
              .length >
          1;
      expect(metaFile, true);
    });

    test('generates Dart helper with fromJson-based methods', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; const Product({required this.id, required this.name}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final config = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      );

      final files = await builder.generate(config);

      final helperFile = files.firstWhere(
        (f) => f.type == 'mock_json_helper',
        orElse: () => throw StateError('No mock_json_helper file found'),
      );

      final helperPath = helperFile.path;
      final helperContent = File(helperPath).readAsStringSync();

      expect(helperContent.contains('class ProductMockJson'), true);
      expect(helperContent.contains('loadProducts()'), true);
      expect(helperContent.contains('loadSampleProduct()'), true);
      expect(helperContent.contains('loadSampleList()'), true);
      expect(helperContent.contains('loadEmptyList()'), true);
      expect(helperContent.contains('fromJson'), true);
      expect(helperContent.contains("'dart:convert'"), true);
      expect(helperContent.contains("'dart:io'"), true);
    });

    test('generates metadata file with hash and field signature', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; const Product({required this.id, required this.name}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final config = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      );

      await builder.generate(config);

      final metaPath = builder.metaFilePathFor('Product', 'catalog');
      expect(File(metaPath).existsSync(), true);

      final metaContent = File(metaPath).readAsStringSync();
      expect(metaContent.contains('generatedHash'), true);
      expect(metaContent.contains('generatedAt'), true);
      expect(metaContent.contains('fieldSignature'), true);
    });

    test('non-overwrite: skips existing JSON without force flag', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; const Product({required this.id, required this.name}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final config = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      );

      await builder.generate(config);

      final jsonPath = builder.jsonFilePathFor('Product', 'catalog');
      final originalContent = File(jsonPath).readAsStringSync();

      final builderNoForce = MockJsonBuilder(outputDir: outputDir);
      final configNoForce = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: false,
      );

      final skippedFiles = await builderNoForce.generate(configNoForce);
      final jsonResult = skippedFiles.firstWhere(
        (f) => f.path == jsonPath,
        orElse: () => throw StateError('File not in results'),
      );

      expect(jsonResult.action, 'skipped');
      final currentContent = File(jsonPath).readAsStringSync();
      expect(currentContent, originalContent);
    });

    test('overwrite: force flag replaces existing JSON', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; const Product({required this.id, required this.name}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final config = GeneratorConfig(
        name: 'Product',
        generateMockJson: true,
        outputDir: outputDir,
        force: true,
      );

      await builder.generate(config);

      final jsonPath = builder.jsonFilePathFor('Product', 'catalog');

      File(jsonPath).writeAsStringSync('[{"id":"custom","name":"manual"}]');

      final forceFiles = await builder.generate(config);
      final jsonResult = forceFiles.firstWhere(
        (f) => f.path == jsonPath,
        orElse: () => throw StateError('File not in results'),
      );

      expect(jsonResult.action, isNot('skipped'));
    });

    test('field mismatch detection warns when fields change', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; final String name; const Product({required this.id, required this.name}); }',
      );

      final builder = MockJsonBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      await builder.generate(
        GeneratorConfig(
          name: 'Product',
          generateMockJson: true,
          outputDir: outputDir,
          force: true,
        ),
      );

      final metaPath = builder.metaFilePathFor('Product', 'catalog');
      final metaContent = File(metaPath).readAsStringSync();
      expect(metaContent.contains('fieldSignature'), true);
      expect(metaContent.contains('id'), true);
      expect(metaContent.contains('name'), true);
    });

    test('dryRun does not write files', () async {
      final entityDir = Directory('$outputDir/domain/entities/catalog/product');
      await entityDir.create(recursive: true);
      final entityFile = File('${entityDir.path}/product.dart');
      await entityFile.writeAsString(
        'class Product { final String id; const Product({required this.id}); }',
      );

      final builder = MockJsonBuilder(outputDir: outputDir);

      await builder.generate(
        GeneratorConfig(
          name: 'Product',
          generateMockJson: true,
          outputDir: outputDir,
          dryRun: true,
        ),
      );

      final jsonPath = builder.jsonFilePathFor('Product', 'catalog');
      expect(File(jsonPath).existsSync(), false);
    });
  });
}
