import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
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
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final initialResult = await initial.generate();
    if (!initialResult.success) {
      print('Initial generation failed: ${initialResult.errors}');
    }
    expect(initialResult.success, isTrue);

    final append = CodeGenerator(
      config: GeneratorConfig(
        name: 'FetchProductStats',
        methods: const [],
        repo: 'Product',
        domain: 'product',
        paramsType: 'QueryParams<Product>',
        returnsType: 'Product',
        appendToExisting: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final appendResult = await append.generate();

    expect(appendResult.success, isTrue);

    final repoFile = File(
      '$outputDir/domain/repositories/product_repository.dart',
    );
    final dataRepoFile = File(
      '$outputDir/data/repositories/data_product_repository.dart',
    );
    final dataSourceFile = File(
      '$outputDir/data/datasources/product/product_datasource.dart',
    );

    // Verify augmentation files do not exist
    expect(
      File(
        '$outputDir/domain/repositories/product_repository.augment.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        '$outputDir/data/repositories/data_product_repository.augment.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        '$outputDir/data/datasources/product/product_datasource.augment.dart',
      ).existsSync(),
      isFalse,
    );

    // Verify direct modification in host files
    final repoSource = repoFile.readAsStringSync();
    expect(repoSource.contains('fetchProductStats'), isTrue);
    expect(repoSource.contains('import augment'), isFalse);

    final dataRepoSource = dataRepoFile.readAsStringSync();
    expect(dataRepoSource.contains('fetchProductStats'), isTrue);
    expect(dataRepoSource.contains('import augment'), isFalse);

    final dataSourceSource = dataSourceFile.readAsStringSync();
    expect(dataSourceSource.contains('fetchProductStats'), isTrue);
    expect(dataSourceSource.contains('import augment'), isFalse);
  });
}
