import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  group('UseCasePlugin Atomic Actions', () {
    late Directory tempDir;
    late UseCasePlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_usecase_test');
      outputDir = tempDir.path;
      plugin = UseCasePlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('create action generates entity usecases', () async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'list'],
        generateData: false,
      );
      
      await plugin.create(config);
      
      final getFile = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      final listFile = File('$outputDir/domain/usecases/product/get_product_list_usecase.dart');
      
      expect(getFile.existsSync(), isTrue);
      expect(listFile.existsSync(), isTrue);
    });

    test('delete action removes entity usecases', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: false,
      );
      await plugin.create(configCreate);
      
      final getFile = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      expect(getFile.existsSync(), isTrue);
      
      // Then delete
      final configDelete = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.delete,
        methods: ['get'],
        generateData: false,
      );
      await plugin.delete(configDelete);
      
      expect(getFile.existsSync(), isFalse);
    });

    test('add action creates new entity usecase', () async {
      // First create get
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateData: false,
      );
      await plugin.create(configCreate);
      
      final getFile = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      expect(getFile.existsSync(), isTrue);
      
      // Then add list
      final configAdd = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['list'],
        generateData: false,
      );
      await plugin.add(configAdd);
      
      final listFile = File('$outputDir/domain/usecases/product/get_product_list_usecase.dart');
      expect(listFile.existsSync(), isTrue);
    });

    test('remove action deletes specific entity usecase', () async {
      // First create get and list
      final configCreate = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'list'],
        generateData: false,
      );
      await plugin.create(configCreate);
      
      final getFile = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      final listFile = File('$outputDir/domain/usecases/product/get_product_list_usecase.dart');
      expect(getFile.existsSync(), isTrue);
      expect(listFile.existsSync(), isTrue);
      
      // Then remove list
      final configRemove = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['list'],
        generateData: false,
      );
      await plugin.remove(configRemove);
      
      expect(getFile.existsSync(), isTrue);
      expect(listFile.existsSync(), isFalse);
    });

    test('create action generates custom usecase', () async {
      final config = GeneratorConfig(
        name: 'Login',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: [], // Empty methods for custom usecase
        domain: 'auth',
        useCaseType: 'future',
      );
      
      await plugin.create(config);
      
      final file = File('$outputDir/domain/usecases/auth/login_usecase.dart');
      expect(file.existsSync(), isTrue);
      
      final content = await file.readAsString();
      expect(content, contains('class LoginUseCase'));
    });

    test('delete action removes custom usecase', () async {
      final config = GeneratorConfig(
        name: 'Login',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: [],
        domain: 'auth',
        useCaseType: 'future',
      );
      await plugin.create(config);
      
      final file = File('$outputDir/domain/usecases/auth/login_usecase.dart');
      expect(file.existsSync(), isTrue);
      
      final configDelete = config.copyWith(action: PluginAction.delete);
      await plugin.delete(configDelete);
      
      expect(file.existsSync(), isFalse);
    });
  });
}
