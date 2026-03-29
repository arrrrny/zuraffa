import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/method_append/method_append_plugin.dart';
import 'package:zuraffa/src/plugins/method_append/capabilities/append_method_capability.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_append_test_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AppendMethodCapability plan returns expected effects', () async {
    final plugin = MethodAppendPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: true,
        force: false,
        verbose: false,
      ),
    );
    final capability = AppendMethodCapability(plugin);

    // Create a dummy repo file
    final repoDir = Directory('$outputDir/domain/repositories');
    await repoDir.create(recursive: true);
    final repoFile = File('${repoDir.path}/user_repository.dart');
    await repoFile.writeAsString('''
abstract class UserRepository {
  Future<void> existingMethod();
}
''');

    final result = await capability.plan({
      'name': 'newMethod',
      'repo': 'UserRepository',
      'outputDir': outputDir,
    });

    expect(result.pluginId, equals('method_append'));
    expect(result.capabilityName, equals('append'));
    expect(result.changes, isNotEmpty);

    final effect = result.changes.first;
    expect(effect.file, contains('user_repository.augment.dart'));
    expect(effect.action, contains('updated'));
  });

  test('AppendMethodCapability execute appends method', () async {
    final plugin = MethodAppendPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final capability = AppendMethodCapability(plugin);

    // Create a dummy repo file
    final repoDir = Directory('$outputDir/domain/repositories');
    await repoDir.create(recursive: true);
    final repoFile = File('${repoDir.path}/order_repository.dart');
    await repoFile.writeAsString('''
abstract class OrderRepository {
  Future<void> existingMethod();
}
''');

    final result = await capability.execute({
      'name': 'createOrder',
      'repo': 'OrderRepository',
      'outputDir': outputDir,
      'params': 'OrderParams',
      'returns': 'Order',
      'force': true,
    });

    expect(result.success, isTrue);
    expect(result.files, isNotEmpty);

    final filePath = result.files.first;
    expect(filePath, contains('order_repository.augment.dart'));

    final file = File(filePath);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('augment class OrderRepository {'));
    expect(content, contains('Future<Order> createOrder(OrderParams params);'));

    // Check host file for 'import augment'
    final hostFile = File('${repoDir.path}/order_repository.dart');
    expect(
      hostFile.readAsStringSync(),
      contains("import augment 'order_repository.augment.dart';"),
    );
  });
}
