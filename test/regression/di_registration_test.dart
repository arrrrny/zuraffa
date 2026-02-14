import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

void main() {
  test('DI registration follows get_it patterns', () async {
    final dir = await Directory.systemTemp.createTemp('zuraffa_di_reg_');
    final outputDir = '${dir.path}/lib/src';
    final plugin = DiPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList'],
        generateData: true,
        generateDi: true,
        outputDir: outputDir,
      ),
    );

    final repoPath = '$outputDir/di/repositories/product_repository_di.dart';
    final dataSourcePath =
        '$outputDir/di/datasources/product_remote_data_source_di.dart';
    final repoContent = File(repoPath).readAsStringSync();
    final dataSourceContent = File(dataSourcePath).readAsStringSync();

    expect(repoContent.contains('getIt.registerLazySingleton'), isTrue);
    expect(repoContent.contains('ProductRepository'), isTrue);
    expect(dataSourceContent.contains('getIt.registerLazySingleton'), isTrue);
    expect(dataSourceContent.contains('ProductRemoteDataSource'), isTrue);

    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });
}
