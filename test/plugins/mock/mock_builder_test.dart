import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';

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
      ),
    );

    expect(files.isNotEmpty, isTrue);
    expect(
      File('$outputDir/data/mock/product_mock_data.dart').existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/data_sources/product/product_mock_data_source.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
