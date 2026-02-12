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
      ),
      'get',
    );

    expect(file.path.endsWith('get_product_usecase_test.dart'), isTrue);
    final testFile = File(file.path);
    expect(testFile.existsSync(), isTrue);
    final content = testFile.readAsStringSync();
    expect(content.contains('class MockProductRepository'), isTrue);
    expect(content.contains('GetProductUseCase'), isTrue);
  });
}
