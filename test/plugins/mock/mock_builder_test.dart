import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

Future<List<String>> _capturePrints(Future<void> Function() body) async {
  final prints = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, String message) {
        prints.add(message);
      },
    ),
  );
  return prints;
}

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates mock data and mock data source', () async {
    final entityDir = Directory('$outputDir/domain/entities/product');
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/product.dart');
    await entityFile.writeAsString(
      'class Product { final String id; const Product(this.id); }',
    );

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    expect(files.isNotEmpty, isTrue);
    expect(
      File('$outputDir/data/mock/product_mock_data.dart').existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/datasources/product/product_mock_datasource.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('appends methods to existing mock datasource', () async {
    final entityDir = Directory('$outputDir/domain/entities/product');
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/product.dart');
    await entityFile.writeAsString(
      'class Product { final String id; const Product(this.id); }',
    );

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    // 1. Initial generation
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final mockFile = File(
      '$outputDir/data/datasources/product/product_mock_datasource.dart',
    );
    expect(mockFile.readAsStringSync().contains('Future<Product> get'), isTrue);
    expect(
      mockFile.readAsStringSync().contains('Future<Product> create'),
      isFalse,
    );

    // 2. Append generation
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['create'],
        appendToExisting: true,
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    expect(mockFile.readAsStringSync().contains('Future<Product> get'), isTrue);
    expect(
      mockFile.readAsStringSync().contains('Future<Product> create'),
      isTrue,
    );
  });

  test('generates mock data with inherited fields', () async {
    // Create superclass Listing
    await Directory(
      '$outputDir/domain/entities/listing',
    ).create(recursive: true);
    final listingFile = File('$outputDir/domain/entities/listing/listing.dart');
    await listingFile.writeAsString(
      'abstract class \$Listing { String get id; }',
    );

    // Create subclass BarcodeListing
    await Directory(
      '$outputDir/domain/entities/barcode_listing',
    ).create(recursive: true);
    final barcodeListingFile = File(
      '$outputDir/domain/entities/barcode_listing/barcode_listing.dart',
    );
    await barcodeListingFile.writeAsString(
      'abstract class \$BarcodeListing implements \$Listing { String get barcode; }',
    );

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await builder.generate(
      GeneratorConfig(
        name: 'BarcodeListing',
        methods: const [],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final mockFile = File(
      '$outputDir/data/mock/barcode_listing_mock_data.dart',
    );
    expect(mockFile.existsSync(), isTrue);
    final content = mockFile.readAsStringSync();

    // Check for inherited 'id' and current 'barcode'
    expect(content.contains("barcode: 'barcode 1'"), isTrue);
    expect(content.contains("id: 'id 1'"), isTrue);
    expect(
      content.contains(
        "BarcodeListing(barcode: 'barcode \$seed', id: 'id \$seed')",
      ),
      isTrue,
    );
  });

  test('generates stream return type for mock custom usecase', () async {
    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await builder.generate(
      GeneratorConfig(
        name: 'ScanBarcode',
        methods: const [],
        domain: 'barcode',
        paramsType: 'NoParams',
        returnsType: 'Barcode',
        useCaseType: 'stream',
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final mockFile = File(
      '$outputDir/data/datasources/scan_barcode/scan_barcode_mock_datasource.dart',
    );
    expect(mockFile.existsSync(), isTrue);
    final content = mockFile.readAsStringSync();
    expect(
      content.contains('Stream<Barcode> scanBarcode(NoParams params)'),
      isTrue,
    );
    expect(content.contains('Stream.fromFuture'), isTrue);
  });

  test('generates mock provider when service is present', () async {
    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final config = GeneratorConfig(
      name: 'GetListingByBarcode',
      service: 'Listing',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'BarcodeListing?',
      generateMock: true,
      outputDir: outputDir,
    );

    final files = await builder.generate(config);

    expect(
      files.any((f) => f.path.contains('listing_mock_provider.dart')),
      isTrue,
    );
    expect(
      files.any((f) => f.path.contains('barcode_listing_mock_data.dart')),
      isTrue,
    );

    final mockProviderFile = File(
      '$outputDir/data/providers/listing/listing_mock_provider.dart',
    );
    expect(mockProviderFile.existsSync(), isTrue);

    final content = mockProviderFile.readAsStringSync();
    expect(content.contains('class ListingMockProvider'), isTrue);
    expect(content.contains('implements ListingService'), isTrue);
    expect(
      content.contains('Future<BarcodeListing?> getListingByBarcode'),
      isTrue,
    );
    expect(
      content.contains('BarcodeListingMockData.sampleBarcodeListing'),
      isTrue,
    );
    expect(
      content.contains("import '../../mock/barcode_listing_mock_data.dart';"),
      isTrue,
    );
    expect(
      content.contains(
        "import '../../../domain/entities/barcode_listing/barcode_listing.dart';",
      ),
      isTrue,
    );
  });

  test('generates stream return type for mock provider', () async {
    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await builder.generate(
      GeneratorConfig(
        name: 'WatchBarcode',
        methods: const [],
        service: 'Barcode',
        domain: 'barcode',
        paramsType: 'NoParams',
        returnsType: 'Barcode',
        useCaseType: 'stream',
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final mockFile = File(
      '$outputDir/data/providers/barcode/barcode_mock_provider.dart',
    );
    expect(mockFile.existsSync(), isTrue);
    final content = mockFile.readAsStringSync();
    expect(
      content.contains('Stream<Barcode> watchBarcode(NoParams params)'),
      isTrue,
    );
    expect(content.contains('Stream.fromFuture'), isTrue);
  });

  test(
    'generates mock provider even if appendToExisting is true and file missing',
    () async {
      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final config = GeneratorConfig(
        name: 'GetListingByBarcode',
        service: 'Listing',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'BarcodeListing?',
        generateMock: true,
        appendToExisting: true, // Should still generate if explicitly requested
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);

      expect(
        files.any((f) => f.path.contains('listing_mock_provider.dart')),
        isTrue,
      );

      final mockProviderFile = File(
        '$outputDir/data/providers/listing/listing_mock_provider.dart',
      );
      expect(mockProviderFile.existsSync(), isTrue);
    },
  );

  test(
    'skips mock data for custom usecase with primitive return type',
    () async {
      final builder = MockBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final config = GeneratorConfig(
        name: 'ScanBarcode',
        service: 'Barcode',
        domain: 'barcode',
        paramsType: 'NoParams',
        returnsType: 'String',
        generateMock: true,
        outputDir: outputDir,
      );

      final files = await builder.generate(config);

      // Mock data file should be skipped (path is empty in GeneratedFile)
      final mockDataFile = files.firstWhere((f) => f.type == 'mock_data');
      expect(mockDataFile.action, equals('skipped'));
      expect(
        File('$outputDir/data/mock/scan_barcode_mock_data.dart').existsSync(),
        isFalse,
      );

      // Mock provider should be generated with hardcoded primitive value
      final mockProviderFile = File(
        '$outputDir/data/providers/barcode/barcode_mock_provider.dart',
      );
      expect(mockProviderFile.existsSync(), isTrue);

      final content = mockProviderFile.readAsStringSync();
      expect(content.contains("return 'mock_value';"), isTrue);
      expect(content.contains("ScanBarcodeMockData"), isFalse);
    },
  );

  test(
    'skips mock data for custom usecase with primitive list return type',
    () async {
      final builder = MockBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final config = GeneratorConfig(
        name: 'GetTags',
        service: 'Tag',
        domain: 'tag',
        paramsType: 'NoParams',
        returnsType: 'List<String>',
        generateMock: true,
        outputDir: outputDir,
      );

      final files = await builder.generate(config);

      // Mock data file should be skipped
      final mockDataFile = files.firstWhere((f) => f.type == 'mock_data');
      expect(mockDataFile.action, equals('skipped'));

      // Mock provider should be generated returning an empty list
      final mockProviderFile = File(
        '$outputDir/data/providers/tag/tag_mock_provider.dart',
      );
      expect(mockProviderFile.existsSync(), isTrue);

      final content = mockProviderFile.readAsStringSync();
      expect(content.contains("return [];"), isTrue);
    },
  );

  test('generates mock data for sealed class concrete subtypes', () async {
    final entityDir = Directory('$outputDir/domain/entities/category_config');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/category_config.dart').writeAsString('''
sealed class CategoryConfig {
  final String id;
  final String name;

  const CategoryConfig({required this.id, required this.name});
}

final class PrimaryCategory extends CategoryConfig {
  const PrimaryCategory({required super.id, required super.name});
}

final class SecondaryCategory extends CategoryConfig {
  const SecondaryCategory({required super.id, required super.name});
}
''');

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'CategoryConfig',
        generateMockDataOnly: true,
        outputDir: outputDir,
      ),
    );

    expect(
      files.where((file) => file.type == 'mock_data').map((f) => f.path),
      containsAll([
        '$outputDir/data/mock/primary_category_mock_data.dart',
        '$outputDir/data/mock/secondary_category_mock_data.dart',
      ]),
    );
    expect(
      File('$outputDir/data/mock/category_config_mock_data.dart').existsSync(),
      isFalse,
    );

    final primaryContent = File(
      '$outputDir/data/mock/primary_category_mock_data.dart',
    ).readAsStringSync();
    final secondaryContent = File(
      '$outputDir/data/mock/secondary_category_mock_data.dart',
    ).readAsStringSync();

    expect(
      primaryContent,
      contains(
        "import '../../domain/entities/category_config/category_config.dart';",
      ),
    );
    expect(primaryContent, contains('PrimaryCategory('));
    expect(secondaryContent, contains('SecondaryCategory('));
  });

  test(
    'skips abstract intermediate sealed subtypes and only generates leaf mocks',
    () async {
      final entityDir = Directory('$outputDir/domain/entities/base');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/base.dart').writeAsString('''
sealed class Base {
  final String id;

  const Base({required this.id});
}

abstract class Middle extends Base {
  const Middle({required super.id});
}

final class Leaf extends Middle {
  const Leaf({required super.id});
}
''');

      final builder = MockBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final files = await builder.generate(
        GeneratorConfig(
          name: 'Base',
          generateMockDataOnly: true,
          outputDir: outputDir,
        ),
      );

      expect(
        files.where((file) => file.type == 'mock_data').map((f) => f.path),
        contains('$outputDir/data/mock/leaf_mock_data.dart'),
      );
      expect(
        File('$outputDir/data/mock/base_mock_data.dart').existsSync(),
        isFalse,
      );
      expect(
        File('$outputDir/data/mock/middle_mock_data.dart').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'warns and skips sealed base classes without concrete subtypes',
    () async {
      final entityDir = Directory('$outputDir/domain/entities/empty_base');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/empty_base.dart').writeAsString('''
sealed class EmptyBase {
  final String id;

  const EmptyBase({required this.id});
}

abstract class EmptyMiddle extends EmptyBase {
  const EmptyMiddle({required super.id});
}
''');

      final builder = MockBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      late List prints;
      late List files;
      prints = await _capturePrints(() async {
        files = await builder.generate(
          GeneratorConfig(
            name: 'EmptyBase',
            generateMockDataOnly: true,
            outputDir: outputDir,
          ),
        );
      });

      expect(files, isEmpty);
      expect(
        File('$outputDir/data/mock/empty_base_mock_data.dart').existsSync(),
        isFalse,
      );
      expect(
        prints.join('\n'),
        contains(
          'No concrete polymorphic subtypes found for sealed entity EmptyBase',
        ),
      );
    },
  );

  test('generates mock data for Zorphy explicit subtypes', () async {
    final entityDir = Directory('$outputDir/domain/entities/template');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/template.dart').writeAsString('''
@Zorphy(explicitSubTypes: [\$SubA, \$SubB])
abstract class Template {
  String get id;
}

final class SubA extends Template {
  final String id;

  const SubA({required this.id});
}

final class SubB extends Template {
  final String id;

  const SubB({required this.id});
}
''');

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Template',
        generateMockDataOnly: true,
        outputDir: outputDir,
      ),
    );

    expect(
      files.where((file) => file.type == 'mock_data').map((f) => f.path),
      containsAll([
        '$outputDir/data/mock/sub_a_mock_data.dart',
        '$outputDir/data/mock/sub_b_mock_data.dart',
      ]),
    );
  });

  test('deduplicates mixed Zorphy and sealed subtype detection', () async {
    final entityDir = Directory('$outputDir/domain/entities/mixed_config');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/mixed_config.dart').writeAsString('''
@Zorphy(explicitSubTypes: [\$PrimaryCategory, \$SecondaryCategory])
sealed class MixedConfig {
  final String id;

  const MixedConfig({required this.id});
}

final class PrimaryCategory extends MixedConfig {
  const PrimaryCategory({required super.id});
}

final class SecondaryCategory extends MixedConfig {
  const SecondaryCategory({required super.id});
}
''');

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'MixedConfig',
        generateMockDataOnly: true,
        outputDir: outputDir,
      ),
    );

    final mockFiles = files.where((file) => file.type == 'mock_data').toList();
    expect(mockFiles, hasLength(2));
    expect(
      mockFiles.map((file) => file.path),
      containsAll([
        '$outputDir/data/mock/primary_category_mock_data.dart',
        '$outputDir/data/mock/secondary_category_mock_data.dart',
      ]),
    );
  });

  test('throws a clear error when the entity file cannot be found', () async {
    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    await expectLater(
      builder.generate(
        GeneratorConfig(
          name: 'NonExistentEntity',
          generateMockDataOnly: true,
          outputDir: outputDir,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Entity file not found for NonExistentEntity'),
        ),
      ),
    );
  });

  test(
    'warns and continues when a nested entity type cannot be resolved',
    () async {
      final entityDir = Directory('$outputDir/domain/entities/product');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/product.dart').writeAsString('''
class Product {
  final String id;
  final MissingDetail detail;

  const Product({required this.id, required this.detail});
}
''');

      final builder = MockBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      late List<String> prints;
      late List files;
      prints = await _capturePrints(() async {
        files = await builder.generate(
          GeneratorConfig(
            name: 'Product',
            generateMockDataOnly: true,
            outputDir: outputDir,
          ),
        );
      });

      expect(files, isNotEmpty);
      expect(
        File('$outputDir/data/mock/product_mock_data.dart').existsSync(),
        isTrue,
      );
      expect(
        prints.join('\n'),
        contains('Unable to resolve nested entity type MissingDetail'),
      );
    },
  );
}
