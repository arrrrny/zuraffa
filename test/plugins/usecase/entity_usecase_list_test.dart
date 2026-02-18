import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_usecase_list_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates entity usecase with list method', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['list'],
      repo: 'Product',
      outputDir: outputDir,
      // Need to specify domain or output structure might vary? 
      // Entity usecases usually derive domain from entity name or similar.
      // But let's see. The generator uses `entitySnake` for folder.
    );
    
    // We expect the file to be generated at lib/src/domain/usecases/product/get_product_list_usecase.dart
    final files = await plugin.generate(config);
    expect(files.length, equals(1));
    final file = files.first;
    final content = file.content ?? await File(file.path).readAsString();
    
    expect(content, contains('class GetProductListUseCase'));
    expect(content, contains('UseCase<List<Product>, ListQueryParams<Product>>'));
    // Verify it calls _repository.list(params)
    expect(content, contains('_repository.list(params)'));
  });

  test('generates entity usecase with getList method (backward compatibility)', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['getList'],
      repo: 'Product',
      outputDir: outputDir,
    );
    
    final files = await plugin.generate(config);
    expect(files.length, equals(1));
    final file = files.first;
    final content = file.content ?? await File(file.path).readAsString();
    
    expect(content, contains('class GetProductListUseCase'));
    expect(content, contains('_repository.getList(params)'));
  });
}
