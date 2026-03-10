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
    expect(mockFile.readAsStringSync().contains('Future<Product> create'), isFalse);

    // 2. Append generation
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['create'],
        appendToExisting: true,
        outputDir: outputDir,
      ),
    );

    expect(mockFile.readAsStringSync().contains('Future<Product> get'), isTrue);
    expect(mockFile.readAsStringSync().contains('Future<Product> create'), isTrue);
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

    expect(files.any((f) => f.path.contains('listing_mock_provider.dart')), isTrue);
    expect(files.any((f) => f.path.contains('barcode_listing_mock_data.dart')), isTrue);
    
    final mockProviderFile = File(
      '$outputDir/data/providers/listing/listing_mock_provider.dart',
    );
    expect(mockProviderFile.existsSync(), isTrue);
    
    final content = mockProviderFile.readAsStringSync();
    expect(content.contains('class ListingMockProvider'), isTrue);
    expect(content.contains('implements ListingService'), isTrue);
    expect(content.contains('Future<BarcodeListing?> getListingByBarcode'), isTrue);
    expect(content.contains('BarcodeListingMockData.sampleBarcodeListing'), isTrue);
    expect(content.contains("import '../../mock/barcode_listing_mock_data.dart';"), isTrue);
  });

  test('generates mock provider even if appendToExisting is true and file missing', () async {
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

    expect(files.any((f) => f.path.contains('listing_mock_provider.dart')), isTrue);
    
    final mockProviderFile = File(
      '$outputDir/data/providers/listing/listing_mock_provider.dart',
    );
    expect(mockProviderFile.existsSync(), isTrue);
  });
}
