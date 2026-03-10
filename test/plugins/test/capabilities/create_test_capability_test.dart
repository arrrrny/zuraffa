import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:zuraffa/src/plugins/test/capabilities/create_test_capability.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_create_test_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CreateTestCapability plan returns expected effects', () async {
    final plugin = TestPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: true,
        force: false,
        verbose: false,
      ),
    );
    final capability = CreateTestCapability(plugin);

    final result = await capability.plan({
      'name': 'Product',
      'methods': ['get'],
      'outputDir': outputDir,
    });

    expect(result.pluginId, equals('test'));
    expect(result.capabilityName, equals('create'));
    expect(result.changes, isNotEmpty);

    final effect = result.changes.first;
    expect(effect.file, contains('get_product_usecase_test.dart'));
  });

  test('CreateTestCapability execute generates files', () async {
    final plugin = TestPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final capability = CreateTestCapability(plugin);

    final result = await capability.execute({
      'name': 'Order',
      'methods': ['create'],
      'outputDir': outputDir,
      'force': true,
    });

    expect(result.success, isTrue);
    expect(result.files, isNotEmpty);

    final filePath = result.files.first;
    expect(filePath, contains('create_order_usecase_test.dart'));

    final file = File(filePath);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('class MockOrderRepository'));
    expect(content, contains('CreateOrderUseCase'));
  });
}
