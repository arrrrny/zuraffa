import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';

void main() {
  group('ControllerPlugin Actions', () {
    late Directory tempDir;
    late ControllerPlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('controller_action_test');
      outputDir = tempDir.path;
      plugin = ControllerPlugin(
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

    test('create action generates controller file', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'list'],
        generateController: true,
      );

      await plugin.create(config);

      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('class ProductController'));
      expect(content, contains('Future<void> getProduct('));
      expect(content, contains('Future<void> getProductList('));
    });

    test('delete action removes controller file', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateController: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);

      // Then delete
      final configDelete = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.delete,
        generateController: true,
      );
      await plugin.delete(configDelete);

      expect(file.existsSync(), isFalse);
    });

    test('add action appends method to controller', () async {
      // First create with 'get'
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateController: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);
      var content = await file.readAsString();
      expect(content, contains('Future<void> getProduct('));
      expect(content, isNot(contains('createProduct')));

      // Then add 'create'
      final configAdd = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['create'],
        generateController: true,
      );
      
      await plugin.add(configAdd);

      content = await file.readAsString();
      expect(content, contains('Future<void> getProduct('));
      expect(content, contains('Future<void> createProduct('));
    });

    test('remove action removes method from controller', () async {
      // First create with 'get' and 'create'
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'create'],
        generateController: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);
      var content = await file.readAsString();
      expect(content, contains('Future<void> getProduct('));
      expect(content, contains('Future<void> createProduct('));

      // Then remove 'create'
      final configRemove = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['create'],
        generateController: true,
      );
      
      await plugin.remove(configRemove);

      content = await file.readAsString();
      expect(content, contains('Future<void> getProduct('));
      expect(content, isNot(contains('createProduct')));
    });
  });
}
