import 'package:args/command_runner.dart';
import '../shadcn_plugin.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../config/zfa_config.dart';
import '../../../cli/plugin_loader.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import 'dart:io';

class ShadcnCommand extends Command<void> {
  final ShadcnPlugin plugin;

  @override
  String get name => 'shadcn';

  @override
  String get description => 'Generate Shadcn UI widgets for entities';

  @override
  String get invocation => 'zfa shadcn <layout> <Entity> [options]';

  ShadcnCommand(this.plugin) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'filter',
      help: 'Enable filtering',
      defaultsTo: false,
    );
    argParser.addFlag(
      'sort',
      help: 'Enable sorting',
      defaultsTo: false,
    );
    argParser.addMultiOption(
      'ignore-fields',
      help: 'Fields to exclude from UI',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder name',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      print('❌ Usage: zfa shadcn <layout> <Entity> [options]');
      print('Available layouts: list, form, grid, table');
      return;
    }

    final layout = rest[0];
    final entityName = rest[1];

    final registry = PluginRegistry.instance;
    final projectRoot = _findProjectRoot('lib/src');
    final manager = PluginManager(
      registry: registry,
      config: ZfaConfig.load(projectRoot: projectRoot),
      pluginConfig: PluginConfig.load(projectRoot: projectRoot),
      projectRoot: projectRoot,
    );

    final activePlugins = [plugin];
    final context = manager.buildContext(
      name: entityName,
      argResults: argResults!,
      activePlugins: activePlugins,
    );

    // Override layout in context data
    context.data['layout'] = layout;

    try {
      print('🚀 Generating Shadcn $layout widget for $entityName...');
      final files = await manager.run(context, activePlugins);

      for (final file in files) {
        print('  ✨ Created: ${file.path}');
      }
      print('✅ Done.');
    } catch (e) {
      print('❌ Failed to generate widget: $e');
    }
  }

  String _findProjectRoot(String outputDir) {
    var dir = Directory.current.path;
    while (dir != Directory(dir).parent.path) {
      if (File('$dir/pubspec.yaml').existsSync()) {
        return dir;
      }
      dir = Directory(dir).parent.path;
    }
    return Directory.current.path;
  }
}
