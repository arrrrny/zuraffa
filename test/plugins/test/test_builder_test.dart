import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/test/builders/test_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_tests_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates usecase test file for entity method', () async {
    final builder = TestBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final file = await builder.generateForMethod(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        repo: 'Product',
        outputDir: outputDir,
      ),
      'get',
    );

    expect(file.path.endsWith('get_product_usecase_test.dart'), isTrue);
    final testFile = File(file.path);
    expect(testFile.existsSync(), isTrue);
    final content = testFile.readAsStringSync();
    expect(content.contains('class MockProductRepository'), isTrue);
    expect(content.contains('GetProductUseCase'), isTrue);
    expect(content.contains('await useCase.call('), isTrue);
    expect(content.contains('expect(result.isSuccess, true)'), isTrue);
  });

  test('generates custom usecase test with params', () async {
    final builder = TestBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final config = GeneratorConfig(
      name: 'GetListingByBarcode',
      domain: 'listing',
      paramsType: 'String',
      repo: 'Listing',
      outputDir: outputDir,
    );

    final file = await builder.generateCustom(config);

    expect(
      file.path.endsWith('get_listing_by_barcode_usecase_test.dart'),
      isTrue,
    );
    final testFile = File(file.path);
    expect(testFile.existsSync(), isTrue);
    final content = testFile.readAsStringSync();

    expect(content.contains('class MockListingRepository'), isTrue);
    expect(content.contains('GetListingByBarcodeUseCase'), isTrue);
    expect(content.contains("await useCase.call('1')"), isTrue);
    expect(content.contains("expect(result.isSuccess, true)"), isTrue);
  });

  test('generates custom usecase test with custom params type', () async {
    final builder = TestBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final config = GeneratorConfig(
      name: 'GetListingByBarcode',
      domain: 'listing',
      paramsType: 'BarcodeParams',
      repo: 'Listing',
      outputDir: outputDir,
    );

    final file = await builder.generateCustom(config);

    expect(
      file.path.endsWith('get_listing_by_barcode_usecase_test.dart'),
      isTrue,
    );
    final testFile = File(file.path);
    expect(testFile.existsSync(), isTrue);
    final content = testFile.readAsStringSync();
    expect(content.contains('class MockBarcodeParams'), isTrue);
  });

  test(
    'includes entity imports for custom usecase params and returns in test',
    () async {
      final builder = TestBuilder(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );

      final config = GeneratorConfig(
        name: 'GetListingByBarcode',
        service: 'Listing',
        domain: 'listing',
        paramsType: 'BarcodeParams',
        returnsType: 'Listing?',
        outputDir: outputDir,
      );

      final file = await builder.generateCustom(config);
      final content = File(file.path).readAsStringSync();

      expect(
        content.contains(
          "import 'package:your_app/src/domain/entities/barcode_params/barcode_params.dart';",
        ),
        isTrue,
      );
      expect(
        content.contains(
          "import 'package:your_app/src/domain/entities/listing/listing.dart';",
        ),
        isTrue,
      );
      expect(
        content.contains('final tBarcodeParams = MockBarcodeParams();'),
        isTrue,
      );
      expect(content.contains('await useCase.call(tBarcodeParams)'), isTrue);
      expect(content.contains('expect(result.isSuccess, true)'), isTrue);
      expect(
        content.contains('registerFallbackValue(MockBarcodeParams())'),
        isTrue,
      );
    },
  );
}
