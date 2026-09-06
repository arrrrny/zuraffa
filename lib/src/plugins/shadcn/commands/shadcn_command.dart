import 'dart:convert';

import 'package:args/command_runner.dart';

import '../capabilities/ui_vocabulary_export_capability.dart';
import '../shadcn_plugin.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../core/plugin_system/capability_invocation_wrapper.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../config/zfa_config.dart';
import '../../../cli/plugin_loader.dart';
import '../../../core/plugin_system/plugin_manager.dart';

import 'dart:io';
import '../../../cli/exit_protocol.dart';

class ShadcnCommand extends Command<void> {
  final ShadcnPlugin plugin;

  @override
  String get name => 'shadcn';

  @override
  String get description => 'Generate Shadcn UI widgets for entities';

  @override
  String get invocation =>
      'zfa shadcn <layout> <Entity> [options]'
      ' | zfa shadcn ui.schema.export [--project-root <dir>]'
      ' [--schema-version <v>]';

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
      // Issue #1149 (kill list — fix list): only implemented layouts are
      // allowed — grid/table were advertised but never implemented.
      allowed: ['list', 'form'],
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
    // SPEC 917 / issue #904 (seed sites 4+5): the ui.schema.export
    // capability's inputSchema declares `projectRoot` and `schemaVersion`
    // — the manifest is a command-invocation contract, so `zfa shadcn
    // ui.schema.export --project-root X --schema-version Y` must parse.
    // Both are honored by the ui.schema.export dispatch branch below.
    argParser.addOption(
      'project-root',
      help:
          'Project root to load UI-vocabulary composites from (ui.schema '
          'export; defaults to the current directory)',
    );
    argParser.addOption(
      'schema-version',
      help:
          'Version stamp for the UI-vocabulary export (ui.schema export; '
          'defaults to the registry version)',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;

    // SPEC 917 / #904 (seed sites 4+5): the ui.schema.export capability is
    // advertised in the manifest and must be invocable from the CLI it
    // advertises itself through. Dispatched before the layout grammar so
    // the dotted capability verb is never mistaken for a layout.
    if (rest.isNotEmpty && rest.first == 'ui.schema.export') {
      await _runUiSchemaExport(rest.skip(1).toList());
      return;
    }

    if (rest.length < 2) {
      print('❌ Usage: zfa shadcn <layout> <Entity> [options]');
      print('Available layouts: list, form');
      exitCode = ExitProtocol.usage;
      return;
    }

    final layout = rest[0];
    final entityName = rest[1];

    // Bug #1139 (exit-code sweep, #856 pattern): an unknown layout is a
    // usage error, not a silent generation of a bogus template. The
    // layout's argParser `allowed` set only guards --layout, never the
    // positional form, so the command itself must refuse here.
    // Issue #1149 (kill list — fix list): only the implemented layouts are
    // accepted. grid/table used to be admitted here and then fell through
    // to the list template — a mislabeled widget that lied about its shape.
    const knownLayouts = {'list', 'form'};
    const unimplementedAdvertised = {'grid', 'table'};
    if (!knownLayouts.contains(layout)) {
      print('❌ Usage: zfa shadcn <layout> <Entity> [options]');
      if (unimplementedAdvertised.contains(layout)) {
        print(
          'Layout "$layout" is not implemented (issue #1149): the old '
          'generator silently emitted a list widget instead. Available '
          'layouts: list, form',
        );
      } else {
        print(
          'Unknown layout: "$layout". '
          'Available layouts: list, form',
        );
      }
      // SPEC 917 canonical usage code (the legacy 64, canonicalized).
      exitCode = ExitProtocol.usage;
      return;
    }

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
      // Bug #1139 (exit-code sweep, #856 pattern): a generation failure is
      // a failure — the process must never exit 0 after printing an error.
      print('❌ Failed to generate widget: $e');
      exitCode = 1;
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

  /// SPEC 917 / #904: the CLI surface of the `ui.schema.export`
  /// capability (spec 024 FR-006). Honors --project-root and
  /// --schema-version exactly as the capability inputSchema declares.
  Future<void> _runUiSchemaExport(List<String> rest) async {
    if (rest.isNotEmpty && !rest.every((a) => !a.startsWith('-'))) {
      print('❌ Usage: zfa shadcn ui.schema.export [options]');
      print(
        '   --> fix: pass --project-root <dir> / --schema-version <v> '
        'as flags, not positionals',
      );
      exitCode = ExitProtocol.usage;
      return;
    }
    final capability = UiVocabularyExportCapability(plugin);
    final result = await capability.execute({
      if (argResults?['project-root'] != null)
        'projectRoot': argResults!['project-root'],
      if (argResults?['schema-version'] != null)
        'schemaVersion': argResults!['schema-version'],
    });
    if (!result.success) {
      print('❌ Failed to export the UI vocabulary schema: ${result.message}');
      print(
        '   --> fix: re-run inside the project whose composites to load '
        '(or pass --project-root <dir>)',
      );
      exitCode = ExitProtocol.failure;
      return;
    }
    print(jsonEncode(result.data?['schema']));
  }
}
