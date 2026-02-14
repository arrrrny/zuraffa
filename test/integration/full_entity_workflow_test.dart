import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

@Timeout(Duration(minutes: 2))
void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('full_entity_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generates full entity workflow', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: const [
        'get',
        'getList',
        'create',
        'update',
        'delete',
        'watchList',
      ],
      generateData: true,
      generateVpc: true,
      generateState: true,
      generateDi: true,
      generateMock: true,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final result = await generator.generate();

    expect(result.success, isTrue);
    expect(
      File(
        '$outputDir/domain/repositories/product_repository.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/repositories/data_product_repository.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/data_sources/product/product_data_source.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/data_sources/product/product_remote_data_source.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/presentation/pages/product/product_view.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/presentation/pages/product/product_controller.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/presentation/pages/product/product_presenter.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/presentation/pages/product/product_state.dart',
      ).existsSync(),
      isTrue,
    );

    final entityFile = File('$outputDir/domain/entities/product/product.dart');
    await entityFile.parent.create(recursive: true);
    await entityFile.writeAsString(
      'class Product { final String id; const Product({required this.id}); }',
    );

    await runDartAnalyze(workspace);
  });
}
