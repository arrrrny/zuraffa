import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/module/module_plugin.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('module_test_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ModuleOrchestratorBuilder', () {
    test('generates orchestrator file with correct class name', () async {
      final plugin = ModuleGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true, verbose: false),
      );
      final config = GeneratorConfig(
        name: 'todo',
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin.generate(config);

      expect(files.length, 1);
      expect(files[0].path, contains('todo_feature_plugin.dart'));
      expect(files[0].action, 'created');

      final content = File(files[0].path).readAsStringSync();
      expect(content, contains('class TodoFeaturePlugin'));
      expect(content, contains("extends ZuraffaPlugin"));
      expect(content, contains("'todo'"));
    });

    test('generates file with pascal-case name handling', () async {
      final plugin = ModuleGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true, verbose: false),
      );
      final config = GeneratorConfig(
        name: 'user_profile',
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin.generate(config);

      expect(files.length, 1);
      final content = File(files[0].path).readAsStringSync();
      expect(content, contains('class UserProfileFeaturePlugin'));
      expect(content, contains("'user_profile'"));
    });
  });
}
