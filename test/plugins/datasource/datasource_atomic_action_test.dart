import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

void main() {
  group('DataSourcePlugin Atomic Actions', () {
    late Directory tempDir;
    late DataSourcePlugin plugin;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ds_atomic_action_test');
      outputDir = tempDir.path;
      plugin = DataSourcePlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: true,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('add action appends method to datasource interface and implementation', () async {
      // First create with 'get'
      final configCreate = GeneratorConfig(
        name: 'User',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get'],
        generateDataSource: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('$outputDir/data/datasources/user/user_datasource.dart');
      final remoteFile = File('$outputDir/data/datasources/user/user_remote_datasource.dart');

      expect(interfaceFile.existsSync(), isTrue);
      expect(remoteFile.existsSync(), isTrue);

      // Then add 'create'
      final configAdd = GeneratorConfig(
        name: 'User',
        outputDir: outputDir,
        action: PluginAction.add,
        methods: ['create'],
        generateDataSource: true,
      );
      await plugin.add(configAdd);

      final interfaceContent = await interfaceFile.readAsString();
      expect(interfaceContent, contains('Future<User> get('));
      expect(interfaceContent, contains('Future<User> create('));

      final remoteContent = await remoteFile.readAsString();
      expect(remoteContent, contains('Future<User> get('));
      expect(remoteContent, contains('Future<User> create('));
    });

    test('remove action removes method from datasource files', () async {
      // First create with 'get' and 'create'
      final configCreate = GeneratorConfig(
        name: 'User',
        outputDir: outputDir,
        action: PluginAction.create,
        methods: ['get', 'create'],
        generateDataSource: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('$outputDir/data/datasources/user/user_datasource.dart');
      final remoteFile = File('$outputDir/data/datasources/user/user_remote_datasource.dart');

      // Then remove 'create'
      final configRemove = GeneratorConfig(
        name: 'User',
        outputDir: outputDir,
        action: PluginAction.remove,
        methods: ['create'],
        generateDataSource: true,
      );
      await plugin.remove(configRemove);

      final interfaceContent = await interfaceFile.readAsString();
      expect(interfaceContent, contains('Future<User> get('));
      expect(interfaceContent, isNot(contains('Future<User> create(')));

      final remoteContent = await remoteFile.readAsString();
      expect(remoteContent, contains('Future<User> get('));
      expect(remoteContent, isNot(contains('Future<User> create(')));
    });
  });
}
