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

    await _expectAnalyzeClean([
      '$outputDir/domain/repositories/product_repository.dart',
      '$outputDir/data/repositories/data_product_repository.dart',
      '$outputDir/data/data_sources/product/product_data_source.dart',
      '$outputDir/presentation/pages/product/product_view.dart',
    ]);
  });
}

Future<Directory> _createWorkspace() async {
  final root = Directory.current.path;
  final dir = Directory(
    '$root/.tmp_integration_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}

Future<void> _expectAnalyzeClean(List<String> paths) async {
  final result = await Process.run('dart', [
    'analyze',
    ...paths,
  ], workingDirectory: Directory.current.path);

  expect(
    result.exitCode,
    equals(0),
    reason: '${result.stdout}\n${result.stderr}',
  );
}
