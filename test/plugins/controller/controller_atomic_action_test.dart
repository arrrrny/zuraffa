import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';

void main() {
  group('ControllerPlugin Atomic Actions', () {
    late Directory tempDir;
    late ControllerPlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_controller_test');
      outputDir = tempDir.path;
      plugin = ControllerPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('create action generates controller', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: false,
        generateController: true,
      );
      
      await plugin.create(config);
      
      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('class ProductController'));
      expect(content, contains('getProduct('));
    });

    test('add action appends method', () async {
      // Create with get
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: false,
        generateController: true,
      );
      await plugin.create(configCreate);
      
      // Add list
      final configAdd = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['list'],
        generateData: false,
        generateController: true,
      );
      await plugin.add(configAdd);
      
      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      final content = await file.readAsString();
      expect(content, contains('getProduct('));
      expect(content, contains('getProductList('));
    });

    test('remove action deletes method', () async {
      // Create with get and list
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'list'],
        generateData: false,
        generateController: true,
      );
      await plugin.create(configCreate);
      
      // Remove list
      final configRemove = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['list'],
        generateData: false,
        generateController: true,
      );
      await plugin.remove(configRemove);
      
      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      final content = await file.readAsString();
      expect(content, contains('getProduct('));
      expect(content, isNot(contains('getProductList(')));
    });

    test('delete action removes controller file', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: false,
        generateController: true,
      );
      await plugin.create(config);
      
      final file = File('$outputDir/presentation/pages/product/product_controller.dart');
      expect(file.existsSync(), isTrue);
      
      final configDelete = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.delete,
        methods: [],
        generateData: false,
        generateController: true,
      );
      await plugin.delete(configDelete);
      
      expect(file.existsSync(), isFalse);
    });
  });
}
