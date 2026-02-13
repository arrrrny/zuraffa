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

Future<Directory> _createWorkspace() async {
  final root = Directory.current.path;
  final dir = Directory(
    '$root/.tmp_integration_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}
