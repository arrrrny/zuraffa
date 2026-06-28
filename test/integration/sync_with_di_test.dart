import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('sync_di');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    await writeEntityStub(workspace, name: 'Product');
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('DI registers all sync components with correct patterns', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList', 'create', 'update', 'delete'],
        generateData: true,
        generateDataSource: true,
        generateDi: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    // Check repository DI
    final repoDiPath = '$outputDir/di/repositories/product_repository_di.dart';
    expect(File(repoDiPath).existsSync(), isTrue);
    final repoDi = File(repoDiPath).readAsStringSync();

    expect(repoDi, contains('registerLazySingleton'));
    expect(repoDi, contains('DataProductRepository'));
    expect(repoDi, contains('ProductLocalDataSource'));
    expect(repoDi, contains('ProductRemoteDataSource'));
    expect(repoDi, contains('SyncMetadataStore'));
    expect(repoDi, contains('SyncStrategy<Product>'));

    // Check local datasource DI
    final localDiPath =
        '$outputDir/di/datasources/product_local_datasource_di.dart';
    expect(File(localDiPath).existsSync(), isTrue);

    // Check remote datasource DI
    final remoteDiPath =
        '$outputDir/di/datasources/product_remote_datasource_di.dart';
    expect(File(remoteDiPath).existsSync(), isTrue);
  });
}
