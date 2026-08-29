/// Tests for SlicePlugin registration and command exposure (T002, T004, T005).
///
/// The plugin must be discoverable through both registration paths the repo
/// uses (`PluginLoader._plugins()` for the CLI and the `CodeGenerator`
/// constructor) so `zfa slice` resolves on every host.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';
import 'package:zuraffa/src/plugins/slice/slice_plugin.dart';

void main() {
  group('SlicePlugin registration', () {
    test('PluginLoader registers the slice plugin (T004)', () {
      final loader = PluginLoader(
        outputDir: Directory.systemTemp.createTempSync('zuraffa_slice_').path,
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig(),
      );

      final ids = loader.listPlugins().map((p) => p.id).toList();
      // `zfa slice ...` only resolves when the loader knows the plugin.
      expect(ids, contains('slice'));
    });

    test('CodeGenerator registers the slice plugin (T005)', () {
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'SliceProbe',
          outputDir: Directory.systemTemp
              .createTempSync('zuraffa_slice_gen_')
              .path,
        ),
        outputDir: Directory.systemTemp.createTempSync(
          'zuraffa_slice_gen_',
        ).path,
      );

      final ids = generator.pluginRegistry.plugins.map((p) => p.id).toList();
      expect(ids, contains('slice'));
    });

    test('SlicePlugin exposes the zfa slice command (T002)', () {
      final plugin = SlicePlugin();
      final command = plugin.createCommand();

      expect(plugin.id, equals('slice'));
      expect(plugin.name, isNotEmpty);
      expect(plugin.version, isNotEmpty);
      expect(command, isA<SliceCommand>());
      expect(command.name, equals('slice'));
    });
  });
}
