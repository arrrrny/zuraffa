import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  group('RepositoryPlugin Actions', () {
    late Directory tempDir;
    late RepositoryPlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('repo_action_test');
      outputDir = tempDir.path;
      plugin = RepositoryPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: false,
        verbose: false,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('create action generates repository interface and implementation', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'list'],
        generateData: true,
      );

      await plugin.create(config);

      final interfaceFile = File('$outputDir/domain/repositories/product_repository.dart');
      final implFile = File('$outputDir/data/repositories/data_product_repository.dart');

      expect(interfaceFile.existsSync(), isTrue);
      expect(implFile.existsSync(), isTrue);

      final interfaceContent = await interfaceFile.readAsString();
      expect(interfaceContent, contains('abstract class ProductRepository'));
      expect(interfaceContent, contains('Future<Product> get('));
      expect(interfaceContent, contains('Future<List<Product>> list('));

      final implContent = await implFile.readAsString();
      expect(implContent, contains('class DataProductRepository implements ProductRepository'));
      expect(implContent, contains('Future<Product> get('));
      expect(implContent, contains('Future<List<Product>> list('));
    });

    test('delete action removes repository files', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('$outputDir/domain/repositories/product_repository.dart');
      final implFile = File('$outputDir/data/repositories/data_product_repository.dart');
      expect(interfaceFile.existsSync(), isTrue);
      expect(implFile.existsSync(), isTrue);

      // Then delete
      final configDelete = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.delete,
        generateData: true,
      );
      await plugin.delete(configDelete);

      expect(interfaceFile.existsSync(), isFalse);
      expect(implFile.existsSync(), isFalse);
    });

    test('add action appends method to repository files', () async {
      // First create with 'get'
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('$outputDir/domain/repositories/product_repository.dart');
      final implFile = File('$outputDir/data/repositories/data_product_repository.dart');

      // Then add 'create'
      final configAdd = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['create'],
        generateData: true,
      );
      
      await plugin.add(configAdd);

      final interfaceContent = await interfaceFile.readAsString();
      expect(interfaceContent, contains('Future<Product> get('));
      expect(interfaceContent, contains('Future<Product> create('));

      final implContent = await implFile.readAsString();
      expect(implContent, contains('Future<Product> get('));
      expect(implContent, contains('Future<Product> create('));
    });

    test('remove action removes method from repository files', () async {
      // First create with 'get' and 'create'
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'create'],
        generateData: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('$outputDir/domain/repositories/product_repository.dart');
      final implFile = File('$outputDir/data/repositories/data_product_repository.dart');

      // Then remove 'create'
      final configRemove = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['create'],
        generateData: true,
      );
      
      await plugin.remove(configRemove);

      final interfaceContent = await interfaceFile.readAsString();
      expect(interfaceContent, contains('Future<Product> get('));
      expect(interfaceContent, isNot(contains('Future<Product> create(')));

      final implContent = await implFile.readAsString();
      expect(implContent, contains('Future<Product> get('));
      expect(implContent, isNot(contains('Future<Product> create(')));
    });
  });
}
