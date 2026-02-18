import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late UseCasePlugin plugin;
  late String outputDir;

  setUp(() {
    outputDir = Directory.systemTemp.createTempSync('zuraffa_test_usecase').path;
    plugin = UseCasePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
  });

  tearDown(() {
    Directory(outputDir).deleteSync(recursive: true);
  });

  group('UseCasePlugin Atomic Actions', () {
    test('create action generates usecase file', () async {
      final config = GeneratorConfig(
        name: 'GetProduct',
        outputDir: outputDir,
        action: PluginAction.create,
        useCaseType: 'future',
        // Minimal config for custom usecase
        domain: 'product',
        repo: 'ProductRepository',
        repoMethod: 'get',
      );

      await plugin.create(config);

      final file = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('class GetProductUseCase'));
      expect(content, contains('Future<void> execute(')); // Default return type is void if not specified
    });

    test('delete action removes usecase file', () async {
      // First create
      final config = GeneratorConfig(
        name: 'GetProduct',
        outputDir: outputDir,
        action: PluginAction.create,
        useCaseType: 'future',
        domain: 'product',
        repo: 'ProductRepository',
        repoMethod: 'get',
      );
      await plugin.create(config);
      final file = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      expect(file.existsSync(), isTrue);

      // Then delete
      final deleteConfig = config.copyWith(action: PluginAction.delete);
      await plugin.delete(deleteConfig);

      expect(file.existsSync(), isFalse);
    });

    test('add action appends method to existing class', () async {
      // Manually create a file with a class but no method
      final file = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      file.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

class GetProductUseCase extends UseCase<void, NoParams> {
  GetProductUseCase();
}
''');

      final config = GeneratorConfig(
        name: 'GetProduct',
        outputDir: outputDir,
        action: PluginAction.add,
        useCaseType: 'future',
        domain: 'product',
        repo: 'ProductRepository',
        repoMethod: 'get',
        // Ensure generator knows to append
      );

      await plugin.add(config);

      final content = await file.readAsString();
      expect(content, contains('class GetProductUseCase'));
      expect(content, contains('Future<void> execute('));
    });

    test('remove action deletes file (default behavior)', () async {
      // First create
      final config = GeneratorConfig(
        name: 'GetProduct',
        outputDir: outputDir,
        action: PluginAction.create,
        useCaseType: 'future',
        domain: 'product',
        repo: 'ProductRepository',
        repoMethod: 'get',
      );
      await plugin.create(config);
      final file = File('$outputDir/domain/usecases/product/get_product_usecase.dart');
      expect(file.existsSync(), isTrue);

      // Then remove
      final removeConfig = config.copyWith(action: PluginAction.remove);
      await plugin.remove(removeConfig);

      expect(file.existsSync(), isFalse);
    });
  });
}
