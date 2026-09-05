import 'package:args/command_runner.dart';

import '../shadcn_plugin.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../core/plugin_system/capability_invocation_wrapper.dart';
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
    argParser.addFlag('filter', help: 'Enable filtering', defaultsTo: false);
    argParser.addFlag('sort', help: 'Enable sorting', defaultsTo: false);
    argParser.addMultiOption(
      'ignore-fields',
      help: 'Fields to exclude from UI',
    );
    argParser.addOption('domain', abbr: 'd', help: 'Domain folder name');
    // The plugin's own configSchema declares `layout` — buildContext's
    // schema merge reads it off argResults, so it must exist as an
    // option (the positional <layout> overrides it into context.data).
    argParser.addOption(
      'layout',
      help: 'UI layout type',
      allowed: ['list', 'grid', 'table', 'form'],
      defaultsTo: 'list',
    );
    // PluginManager.buildContext reads the standard PluginCommand flags
    // AND the core generation params off argResults; without them
    // `zfa shadcn <layout> <Entity>` died with "Could not find an option
    // named --dry-run / --layout / --methods" before a single widget was
    // generated (found while wiring the issue #996 receipt — mirrors
    // MakeCommand._addCoreOptions).
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
    argParser.addMultiOption('methods', help: 'Entity methods to wire');
    argParser.addMultiOption('usecases', help: 'UseCases to orchestrate');
    argParser.addMultiOption('variants', help: 'Polymorphic variants');
    argParser.addOption('repo', help: 'Repository to inject');
    argParser.addOption('service', help: 'Service to inject');
    argParser.addOption('id-field', help: 'ID field name', defaultsTo: 'id');
    argParser.addOption(
      'id-field-type',
      help: 'ID field type',
      defaultsTo: 'String',
    );
    argParser.addOption('query-field', help: 'Query field name');
    argParser.addOption('query-field-type', help: 'Query field type');
    argParser.addFlag('no-entity', negatable: false, help: 'Skip entity');
    argParser.addFlag('vpc', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('vpcs', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('state', negatable: false, help: 'Generate state class');
    argParser.addFlag('di', negatable: false, help: 'Generate DI wiring');
    argParser.addFlag('data', negatable: false, help: 'Generate data layer');
    argParser.addFlag(
      'datasource',
      negatable: false,
      help: 'Generate data source',
    );
    argParser.addFlag('cache', negatable: false, help: 'Enable caching');
    argParser.addFlag('sqlite', negatable: false, help: 'SQLite data source');
    argParser.addFlag('route', negatable: false, help: 'Generate route');
    argParser.addFlag('mock', negatable: false, help: 'Generate mock data');
    argParser.addFlag('test', negatable: false, help: 'Generate tests');
    argParser.addFlag(
      'append',
      negatable: false,
      help: 'Append to existing repo/service',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      print('❌ Usage: zfa shadcn <layout> <Entity> [options]');
      print('Available layouts: list, form, grid, table');
      exitCode = 64;
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

      // Issue #996: `zfa shadcn <layout> <Entity>` is a standalone
      // invocation — it ships the same capability receipt as
      // `zfa di create` & co. (plugin `shadcn`, capability = layout).
      // manager.run already persists the make-path receipt; this one
      // carries the {plugin, capability, entity, hash, methodset, files,
      // receipt_version} envelope.
      await CapabilityInvocationWrapper(
        capability: NamedCapability(layout),
        pluginId: plugin.id,
        projectRoot: projectRoot,
      ).persistReceipt(
        args: {'name': entityName, 'layout': layout},
        result: ExecutionResult(
          success: true,
          files: files.map((f) => f.path).toList(),
          data: {'generatedFiles': files},
        ),
      );

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
