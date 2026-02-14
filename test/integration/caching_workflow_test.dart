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
    workspace = await createWorkspace('caching_workflow_test');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generates caching workflow with remote and local datasource', () async {
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'getList'],
      generateData: true,
      enableCache: true,
      cacheStorage: 'hive',
      generateDi: true,
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
        '$outputDir/data/data_sources/order/order_remote_data_source.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/data_sources/order/order_local_data_source.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/repositories/data_order_repository.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
