import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late ServicePlugin plugin;
  late String outputDir;

  setUp(() {
    outputDir = Directory.systemTemp.createTempSync('zuraffa_test_service').path;
    plugin = ServicePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
  });

  tearDown(() {
    Directory(outputDir).deleteSync(recursive: true);
  });

  group('ServicePlugin Atomic Actions', () {
    test('create action generates service interface', () async {
      final config = GeneratorConfig(
        name: 'Login', // Name of the action/method usually, but ServicePlugin might use this differently
        outputDir: outputDir,
        action: PluginAction.create,
        service: 'AuthService',
        serviceMethod: 'login',
        paramsType: 'LoginParams',
        returnsType: 'AuthToken',
      );

      await plugin.create(config);

      final file = File('$outputDir/domain/services/auth_service.dart');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('abstract class AuthService'));
      expect(content, contains('Future<AuthToken> login(LoginParams params);'));
    });

    test('delete action removes service interface', () async {
      // First create
      final config = GeneratorConfig(
        name: 'Login',
        outputDir: outputDir,
        action: PluginAction.create,
        service: 'AuthService',
        serviceMethod: 'login',
      );
      await plugin.create(config);
      final file = File('$outputDir/domain/services/auth_service.dart');
      expect(file.existsSync(), isTrue);

      // Then delete
      final deleteConfig = config.copyWith(action: PluginAction.delete);
      await plugin.delete(deleteConfig);

      expect(file.existsSync(), isFalse);
    });

    test('add action appends method to existing service', () async {
      // First create with login
      final config = GeneratorConfig(
        name: 'Login',
        outputDir: outputDir,
        action: PluginAction.create,
        service: 'AuthService',
        serviceMethod: 'login',
      );
      await plugin.create(config);

      // Then add logout
      final addConfig = GeneratorConfig(
        name: 'Logout',
        outputDir: outputDir,
        action: PluginAction.add,
        service: 'AuthService',
        serviceMethod: 'logout',
        paramsType: 'NoParams',
        returnsType: 'void',
      );
      await plugin.add(addConfig);

      final file = File('$outputDir/domain/services/auth_service.dart');
      final content = await file.readAsString();
      expect(content, contains('Future<void> login(')); // void because no return type specified in create
      expect(content, contains('Future<void> logout('));
    });

    test('remove action removes method from service', () async {
      // First create with login and logout
      final config = GeneratorConfig(
        name: 'Login',
        outputDir: outputDir,
        action: PluginAction.create,
        service: 'AuthService',
        serviceMethod: 'login',
      );
      await plugin.create(config);

      final addConfig = GeneratorConfig(
        name: 'Logout',
        outputDir: outputDir,
        action: PluginAction.add,
        service: 'AuthService',
        serviceMethod: 'logout',
      );
      await plugin.add(addConfig);

      final file = File('$outputDir/domain/services/auth_service.dart');
      var content = await file.readAsString();
      expect(content, contains('login'));
      expect(content, contains('logout'));

      // Then remove login
      final removeConfig = config.copyWith(action: PluginAction.remove);
      await plugin.remove(removeConfig);

      content = await file.readAsString();
      expect(content, isNot(contains('login')));
      expect(content, contains('logout'));
    });
  });
}
