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

  test('generates multiple entities without conflicts', () async {
    final product = CodeGenerator(
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
    final order = CodeGenerator(
      config: GeneratorConfig(
        name: 'Order',
        methods: const ['getList'],
        generateData: true,
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
        '$outputDir/data/data_sources/product/product_remote_data_source.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/data_sources/order/order_remote_data_source.dart',
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
