import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Integration test: JSON → Morphy Entities → build_runner
///
/// Tests the complete pipeline end-to-end
void main() {
  group('Integration Test: Full Pipeline', () {
    late String testProjectPath;
    late ZuraffaGenerator generator;

    setUp(() {
      testProjectPath = Directory.systemTemp
          .createTempSync('zuraffa_integration_')
          .path;
      generator = ZuraffaGenerator(testProjectPath);
    });

    tearDown(() {
      try {
        Directory(testProjectPath).deleteSync(recursive: true);
      } catch (_) {}
    });

    test('should generate simple Product entity from JSON', () async {
      final json = {
        'id': 'prod-123',
        'name': 'iPhone 15 Pro',
        'price': 999.99,
        'inStock': true,
      };

      final result = await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false, // Skip build_runner in test
        onProgress: (msg) => print(msg),
      );

      expect(result.success, true);
      expect(result.entityFiles.length, 1);
      expect(result.entityFiles[0], 'lib/src/domain/entities/product.dart');

      // Verify file was written
      final fileWriter = FileWriter(testProjectPath);
      final content = await fileWriter.readFile(result.entityFiles[0]);

      expect(content, contains('@morphy'));
      expect(content, contains('@Morphy(generateJson: true)'));
      expect(content, contains('abstract class \$Product'));
      expect(content, contains('String get id;'));
      expect(content, contains('String get name;'));
      expect(content, contains('double get price;'));
      expect(content, contains('bool get inStock;'));
    });

    test('should generate nested entities from ZikZak JSON', () async {
      final json = {
        'comparisonId': 'cmp-123',
        'query': 'iPhone 15 Pro',
        'results': [
          {
            'merchant': 'Amazon',
            'price': 999.99,
            'currency': 'USD',
            'shipping': {
              'cost': 0.0,
              'estimatedDays': 2,
            },
            'lastChecked': '2025-11-14T12:00:00Z',
          },
        ],
      };

      final result = await generator.generateFromJson(
        json,
        entityName: 'PriceComparison',
        runBuildRunner: false,
        onProgress: (msg) => print(msg),
      );

      expect(result.success, true);
      expect(result.entityFiles.length, 3);

      // Main entity
      expect(
        result.entityFiles,
        contains('lib/src/domain/entities/price_comparison.dart'),
      );

      // Nested entity
      expect(
        result.entityFiles,
        contains('lib/src/domain/entities/result.dart'),
      );

      // Deeply nested entity
      expect(
        result.entityFiles,
        contains('lib/src/domain/entities/shipping.dart'),
      );

      // Verify main entity content
      final fileWriter = FileWriter(testProjectPath);
      final mainContent = await fileWriter.readFile(
        'lib/src/domain/entities/price_comparison.dart',
      );

      expect(mainContent, contains('abstract class \$PriceComparison'));
      expect(mainContent, contains('String get comparisonId;'));
      expect(mainContent, contains('List<\$Result> get results;')); // $ prefix!

      // Verify nested entity content
      final resultContent = await fileWriter.readFile(
        'lib/src/domain/entities/result.dart',
      );

      expect(resultContent, contains('abstract class \$Result'));
      expect(resultContent, contains('\$Shipping get shipping;')); // $ prefix!
      expect(resultContent, contains('DateTime get lastChecked;')); // DateTime type
    });

    test('should handle arrays of primitives', () async {
      final json = {
        'productId': 'p1',
        'tags': ['electronics', 'phone', 'apple'],
        'ratings': [4.5, 4.8, 5.0],
      };

      final result = await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false,
      );

      final fileWriter = FileWriter(testProjectPath);
      final content = await fileWriter.readFile(result.entityFiles[0]);

      expect(content, contains('List<String> get tags;')); // No $ for primitives
      expect(content, contains('List<double> get ratings;'));
    });

    test('should handle nullable fields', () async {
      final json = {
        'id': 'p1',
        'name': 'Product',
        'discount': null,
      };

      final result = await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false,
      );

      final fileWriter = FileWriter(testProjectPath);
      final content = await fileWriter.readFile(result.entityFiles[0]);

      expect(content, contains('String get id;')); // Non-nullable
      expect(content, contains('String get name;')); // Non-nullable
      expect(content, contains('dynamic? get discount;')); // Nullable
    });

    test('should detect when build_runner is needed', () async {
      final json = {'id': '1', 'name': 'Test'};

      // Generate entities
      await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false,
      );

      // Check if build_runner detects the need
      final buildRunner = BuildRunnerManager(testProjectPath);
      final needsGeneration = await buildRunner.needsGeneration();

      expect(needsGeneration, true); // .g.dart doesn't exist yet
    });

    test('should create build.yaml automatically', () async {
      final json = {'id': '1', 'name': 'Test'};

      // Generate entities
      final result = await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false,
      );

      expect(result.buildYamlCreated, true);

      // Verify build.yaml was written
      final fileWriter = FileWriter(testProjectPath);
      final buildYamlExists = await fileWriter.fileExists('build.yaml');
      expect(buildYamlExists, true);

      // Verify content
      final buildYamlContent = await fileWriter.readFile('build.yaml');
      expect(buildYamlContent, contains('morphy_builder'));
      expect(buildYamlContent, contains('lib/src/domain/entities/*.dart'));
      expect(buildYamlContent, contains('generate_json: true'));
    });

    test('should not recreate build.yaml if already configured', () async {
      final json = {'id': '1', 'name': 'Test'};

      // First generation - creates build.yaml
      final result1 = await generator.generateFromJson(
        json,
        entityName: 'Product',
        runBuildRunner: false,
      );
      expect(result1.buildYamlCreated, true);

      // Second generation - should not recreate
      final result2 = await generator.generateFromJson(
        json,
        entityName: 'Order',
        runBuildRunner: false,
      );
      expect(result2.buildYamlCreated, false);
    });
  });

  group('Integration Test: File Paths', () {
    test('should convert entity names to correct file paths', () {
      final generator = MorphyEntityGenerator();

      expect(
        generator.getFilePath('Product'),
        'lib/src/domain/entities/product.dart',
      );

      expect(
        generator.getFilePath('PriceComparison'),
        'lib/src/domain/entities/price_comparison.dart',
      );

      expect(
        generator.getFilePath('OrderItem'),
        'lib/src/domain/entities/order_item.dart',
      );
    });
  });
}
