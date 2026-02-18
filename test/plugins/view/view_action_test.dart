import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  group('ViewPlugin Actions', () {
    late Directory tempDir;
    late ViewPlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('view_action_test');
      outputDir = tempDir.path;
      plugin = ViewPlugin(
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

    test('create action generates view file', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        generateView: true,
      );

      await plugin.create(config);

      final file = File('$outputDir/presentation/pages/product/product_view.dart');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('class ProductView extends CleanView'));
    });

    test('delete action removes view file', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        generateView: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_view.dart');
      expect(file.existsSync(), isTrue);

      // Then delete
      final configDelete = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.delete,
        generateView: true,
      );
      await plugin.delete(configDelete);

      expect(file.existsSync(), isFalse);
    });

    test('add action does nothing', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        generateView: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_view.dart');
      expect(file.existsSync(), isTrue);
      final originalContent = await file.readAsString();

      // Then add
      final configAdd = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.add,
        generateView: true,
        methods: ['newMethod'],
      );
      
      final result = await plugin.add(configAdd);

      expect(result, isEmpty);
      final newContent = await file.readAsString();
      expect(newContent, equals(originalContent));
    });

    test('remove action does nothing', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        generateView: true,
      );
      await plugin.create(configCreate);

      final file = File('$outputDir/presentation/pages/product/product_view.dart');
      expect(file.existsSync(), isTrue);
      final originalContent = await file.readAsString();

      // Then remove
      final configRemove = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.remove,
        generateView: true,
        methods: ['get'],
      );
      
      final result = await plugin.remove(configRemove);

      expect(result, isEmpty);
      final newContent = await file.readAsString();
      expect(newContent, equals(originalContent));
    });
  });
}
