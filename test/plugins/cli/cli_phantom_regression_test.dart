// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// cli phantom-output fix.
//
// RED (pre-fix): `zfa make Product --with=cli` printed
// "Generation complete: lib/src/cli/commands/product_command.dart" and
// exited 0 — but CliGeneratorPlugin.generateWithContext returned a
// GeneratedFile WITHOUT persisting it, and PluginManager.run only
// collects returned files (persistence happens inside builders that call
// FileUtils.writeFile). Nobody ever wrote the content: the file did not
// exist. This suite pins the minimum viable honesty fix: the plugin
// persists its own output through FileUtils.writeFile.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_manager.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/cli/cli_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cli_phantom_test_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('CliGeneratorPlugin.generateWithContext persists output', () {
    test('writes <entity>_command.dart under <outputDir>/cli/commands',
        () async {
      final plugin = CliGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      // Build a real context through the manager so the transactional
      // filesystem and core flags behave exactly like the make pipeline.
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: tempDir.path,
      );
      final activePlugins = <dynamic>[plugin];
      final context = manager.buildContext(
        name: 'Product',
        argResults: null,
        activePlugins: activePlugins.cast(),
        overrideOutputDir: outputDir,
        overrideForce: true,
      );

      final files = await plugin.generateWithContext(context);

      expect(files, hasLength(1));
      final onDisk = File(files.first.path);
      expect(
        onDisk.existsSync(),
        isTrue,
        reason:
            'The generated CLI command file must exist on disk. Pre-fix, '
            'generateWithContext returned content nobody persisted — the '
            'CLI printed "Generated:" for a phantom file.',
      );
      expect(files.first.path, endsWith('product_command.dart'));
      expect(files.first.path, contains('$outputDir/cli/commands'));
      expect(onDisk.readAsStringSync(), contains('class ProductCommand'));
    });

    test('dry-run does not write', () async {
      final plugin = CliGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: true),
      );
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: tempDir.path,
      );
      final context = manager.buildContext(
        name: 'Product',
        argResults: null,
        activePlugins: [plugin],
        overrideOutputDir: outputDir,
        overrideDryRun: true,
      );

      final files = await plugin.generateWithContext(context);

      expect(files, hasLength(1));
      expect(
        File(files.first.path).existsSync(),
        isFalse,
        reason: 'dry-run must preview without persisting',
      );
    });

    test('standalone generate(config) also persists (legacy entry point)',
        () async {
      final plugin = CliGeneratorPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );

      final files = await plugin.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir, force: true),
      );

      expect(files, hasLength(1));
      expect(File(files.first.path).existsSync(), isTrue,
          reason: 'the legacy generate() path must not regress to phantom');
      expect(
        File(files.first.path).readAsStringSync(),
        contains('extends StandardCommand'),
      );
    });
  });
}
