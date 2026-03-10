import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      final builder = MockBuilder(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );

      final plugin = MockPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
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
        dryRun: false,
        force: true,
        verbose: false,
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
        dryRun: false,
        force: true,
        verbose: false,
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
}
