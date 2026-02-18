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
    workspace = await createWorkspace('multi_entity');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generates multiple entities without conflicts', () async {
    final product = CodeGenerator(
      config: GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final order = CodeGenerator(
      config: GeneratorConfig(
        name: 'Order',
        methods: const ['getList'],
        generateData: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final productResult = await product.generate();
    final orderResult = await order.generate();

    expect(productResult.success, isTrue);
    expect(orderResult.success, isTrue);
    expect(
      File(
        '$outputDir/domain/repositories/product_repository.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('$outputDir/domain/repositories/order_repository.dart').existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/datasources/product/product_remote_datasource.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/datasources/order/order_remote_datasource.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
