import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

void main() {
  group('DataSourcePlugin Actions', () {
    late DataSourcePlugin plugin;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('datasource_action_test');
      plugin = DataSourcePlugin(
        outputDir: tempDir.path,
        dryRun: false,
        force: true,
        verbose: false,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('create action generates datasource files', () async {
      final config = GeneratorConfig(
        name: 'User',
        outputDir: tempDir.path,
        action: PluginAction.create,
        methods: ['get'],
        generateDataSource: true,
        verbose: true,
      );
      final result = await plugin.create(config);
      print('Result files: ${result.length}');
      for (final f in result) {
        print('  ${f.path} (${f.action})');
      }

      final interfaceFile = File('${tempDir.path}/data/datasources/user/user_datasource.dart');
      final remoteFile = File('${tempDir.path}/data/datasources/user/user_remote_datasource.dart');

      expect(interfaceFile.existsSync(), isTrue);
      expect(remoteFile.existsSync(), isTrue);
      
      final content = interfaceFile.readAsStringSync();
      expect(content, contains('abstract class UserDataSource'));
      expect(content, contains('Future<User> get'));
    });

    test('delete action removes datasource files', () async {
      // First create
      final configCreate = GeneratorConfig(
        name: 'User',
        outputDir: tempDir.path,
        action: PluginAction.create,
        methods: ['get'],
        generateDataSource: true,
      );
      await plugin.create(configCreate);

      final interfaceFile = File('${tempDir.path}/data/datasources/user/user_datasource.dart');
      final remoteFile = File('${tempDir.path}/data/datasources/user/user_remote_datasource.dart');
      expect(interfaceFile.existsSync(), isTrue);
      expect(remoteFile.existsSync(), isTrue);

      // Then delete
      final configDelete = GeneratorConfig(
        name: 'User',
        outputDir: tempDir.path,
        action: PluginAction.delete,
        generateDataSource: true, // Required for now
      );
      await plugin.delete(configDelete);

      expect(interfaceFile.existsSync(), isFalse);
      // Remote file should also be deleted if logic supports it
      // Current logic: if generateLocal is false (default), it deletes remote.
      expect(remoteFile.existsSync(), isFalse);
    });
  });
}
