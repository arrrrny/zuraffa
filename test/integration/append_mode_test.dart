import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('append_mode');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
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
