import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  group('ServicePlugin Atomic Actions', () {
    late Directory tempDir;
    late ServicePlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('service_action_test');
      outputDir = tempDir.path;
      plugin = ServicePlugin(
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

    test('create action generates service interface', () async {
      final config = GeneratorConfig(
        name: 'Auth',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['login'],
        generateData: true,
        service: 'Auth',
      );

      await plugin.create(config);

      final serviceFile = File('$outputDir/domain/services/auth_service.dart');
      expect(serviceFile.existsSync(), isTrue);

      final content = await serviceFile.readAsString();
      expect(content, contains('abstract class AuthService'));
      expect(content, contains('Future<void> login('));
    });

    test('add action appends method to service interface', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'Auth',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['login'],
        generateData: true,
        service: 'Auth',
      );
      await plugin.create(configCreate);

      // Then add 'logout'
      final configAdd = GeneratorConfig(
        name: 'Auth',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['logout'],
        generateData: true,
        service: 'Auth',
      );
      
      await plugin.add(configAdd);

      final serviceFile = File('$outputDir/domain/services/auth_service.dart');
      final content = await serviceFile.readAsString();
      expect(content, contains('Future<void> login('));
      expect(content, contains('Future<void> logout('));
    });

    test('remove action removes method from service interface', () async {
      // First create with 'login' and 'logout'
      final configCreate = GeneratorConfig(
        name: 'Auth',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['login', 'logout'],
        generateData: true,
        service: 'Auth',
      );
      await plugin.create(configCreate);

      // Then remove 'logout'
      final configRemove = GeneratorConfig(
        name: 'Auth',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['logout'],
        generateData: true,
        service: 'Auth',
      );
      
      await plugin.remove(configRemove);

      final serviceFile = File('$outputDir/domain/services/auth_service.dart');
      final content = await serviceFile.readAsString();
      expect(content, contains('Future<void> login('));
      expect(content, isNot(contains('Future<void> logout(')));
    });
  });
}
