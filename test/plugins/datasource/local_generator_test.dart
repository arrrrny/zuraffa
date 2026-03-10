import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/builders/local_generator.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_local_ds_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates hive-backed local datasource', () async {
    final builder = LocalDataSourceBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final file = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList'],
        generateLocal: true,
        outputDir: outputDir,
      ),
    );

    expect(file.path.endsWith('product_local_datasource.dart'), isTrue);
    final content = File(file.path).readAsStringSync();
    expect(content.contains('class ProductLocalDataSource'), isTrue);
    expect(content.contains('Box<Product>'), isTrue);
  });
}
