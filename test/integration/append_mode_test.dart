import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory workspaceDir;
  late String outputDir;

  setUp(() async {
    workspaceDir = await _createWorkspace();
    outputDir = '${workspaceDir.path}/lib/src';
  });

  tearDown(() async {
    if (workspaceDir.existsSync()) {
      await workspaceDir.delete(recursive: true);
    }
  });

  test('append mode updates repository and datasources', () async {
    final initial = CodeGenerator(
      config: GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
      ),
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final initialResult = await initial.generate();
    expect(initialResult.success, isTrue);

    final append = CodeGenerator(
      config: GeneratorConfig(
        name: 'FetchProductStats',
        methods: const [],
        repo: 'Product',
        paramsType: 'QueryParams<Product>',
        returnsType: 'Product',
        appendToExisting: true,
      ),
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final appendResult = await append.generate();

    expect(appendResult.success, isTrue);

    final repoContent = File(
      '$outputDir/domain/repositories/product_repository.dart',
    ).readAsStringSync();
    final dataRepoContent = File(
      '$outputDir/data/repositories/data_product_repository.dart',
    ).readAsStringSync();
    final dataSourceContent = File(
      '$outputDir/data/data_sources/product/product_data_source.dart',
    ).readAsStringSync();

    expect(repoContent.contains('fetchProductStats'), isTrue);
    expect(dataRepoContent.contains('fetchProductStats'), isTrue);
    expect(dataSourceContent.contains('fetchProductStats'), isTrue);
  });
}

Future<Directory> _createWorkspace() async {
  final root = Directory.current.path;
  final dir = Directory(
    '$root/.tmp_integration_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}
