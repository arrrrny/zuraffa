// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// module merge — one generator for the FeaturePlugin class.
//
// RED (pre-fix): ModuleOrchestratorBuilder emitted
// `Map<String, ZuraffaRouteBuilder> get routes`, but the core
// ZuraffaPlugin contract (lib/src/core/module/zuraffa_plugin.dart)
// declares `Map<String, ZuraffaRouteHandler>` — ZuraffaRouteBuilder does
// not exist in package:zuraffa, so every generated orchestrator failed
// to compile. Meanwhile `zfa module` scaffolded a SECOND, independent
// string-template copy of the same class (already drifting).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/module/builders/module_orchestrator_builder.dart';
import 'package:zuraffa/src/plugins/module/module_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('module_merge_test_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('ModuleOrchestratorBuilder emits core-contract code', () {
    test('routes uses ZuraffaRouteHandler (exists in core)', () async {
      final builder = ModuleOrchestratorBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'todo', outputDir: outputDir, force: true),
      );

      expect(files, hasLength(1));
      final content = File(files.first.path).readAsStringSync();
      expect(
        content,
        contains('Map<String, ZuraffaRouteHandler>'),
        reason:
            'The core ZuraffaPlugin contract declares routes as '
            'Map<String, ZuraffaRouteHandler>. ZuraffaRouteBuilder does '
            'not exist in package:zuraffa — the pre-merge generated code '
            'could not compile.',
      );
      expect(content, isNot(contains('ZuraffaRouteBuilder')));
    });

    test(
      'generated orchestrator satisfies the core contract members',
      () async {
        final builder = ModuleOrchestratorBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'todo', outputDir: outputDir, force: true),
        );
        final content = File(files.first.path).readAsStringSync();

        expect(content, contains('class TodoFeaturePlugin'));
        expect(content, contains('extends ZuraffaPlugin'));
        expect(content, contains("'todo'"));
        expect(content, contains('pluginId'));
        expect(content, contains('registerDependencies(ZuraffaDIContainer'));
        expect(content, contains("import 'package:zuraffa/zuraffa.dart'"));
      },
    );
  });

  group('ModuleGeneratorPlugin (make pipeline surface)', () {
    test('delegates to the same orchestrator builder', () async {
      final plugin = ModuleGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await plugin.generate(
        GeneratorConfig(name: 'todo', outputDir: outputDir, force: true),
      );

      expect(files, hasLength(1));
      final content = File(files.first.path).readAsStringSync();
      expect(content, contains('class TodoFeaturePlugin'));
      expect(
        content,
        isNot(contains('ZuraffaRouteBuilder')),
        reason: 'both entry points must emit core-contract code',
      );
    });
  });
}
