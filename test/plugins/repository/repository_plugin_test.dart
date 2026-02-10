import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_repo_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates repository interface', () async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get', 'getList'],
      generateRepository: true,
    );
    final files = await plugin.generate(config);
    expect(files.isNotEmpty, isTrue);
    final content = files.first.content ?? '';
    expect(content.contains('abstract class ProductRepository'), isTrue);
    expect(content.contains('Future<Product> get'), isTrue);
    expect(content.contains('Future<List<Product>> getList'), isTrue);
  });

  test('generates data repository implementation', () async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Order',
      methods: ['get'],
      generateData: true,
    );
    final files = await plugin.generate(config);
    expect(files.length, equals(2));
    final impl =
        files.firstWhere((f) => f.path.contains('data_order_repository.dart'));
    final content = impl.content ?? '';
    expect(content.contains('class DataOrderRepository'), isTrue);
    expect(content.contains('implements OrderRepository'), isTrue);
  });

  test('append mode preserves existing methods', () async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );
    final filePath =
        '${outputDir}/domain/repositories/user_repository.dart';
    await File(filePath).create(recursive: true);
    await File(filePath).writeAsString(
      "import 'package:zuraffa/zuraffa.dart';\n\nabstract class UserRepository {\n  Future<void> custom();\n}\n",
    );
    final config = GeneratorConfig(
      name: 'User',
      methods: ['get'],
      appendToExisting: true,
      generateRepository: true,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('custom()'), isTrue);
    expect(content.contains('Future<User> get'), isTrue);
  });
}
