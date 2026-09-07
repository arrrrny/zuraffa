import 'dart:convert';

import 'package:args/command_runner.dart';

import '../capabilities/ui_vocabulary_export_capability.dart';
import '../skin_plugin.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../core/plugin_system/capability_invocation_wrapper.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../config/zfa_config.dart';
import '../../../cli/plugin_loader.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/context/file_system.dart';
// Spec 1276: the `zfa skin` top-level surface is ONE command owned by
// the skin plugin. The runtime skin-contract auditor subcommands
// (issue #1102/#1112 — `skin kit`, `skin verify`, `skin drive`) ride on
// it as subcommands, preserving their issue-#1102 CLI surface exactly.
import '../../../commands/skin_command.dart' as audit;

import 'dart:io';
import '../../../cli/exit_protocol.dart';

/// The `zfa skin` command group (spec 1276).
///
/// Owns three grammars:
/// 1. Generation — `zfa skin <layout> <Entity>` as registered layout
///    subcommands (`list`, `form`), parallel to `zfa ui schema`.
/// 2. Capability — `zfa skin ui.schema.export` (spec 024 FR-006, the
///    #904 flag surface), a real subcommand so `zfa manifest --verify`
///    resolves the serving command's parser mechanically.
/// 3. Auditor — `skin kit | verify | drive` (issue #1102/#1112),
///    mounted verbatim from the runtime skin-contract auditor.
///
/// Advertised-but-unimplemented layouts (`grid`, `table`) are registered
/// as refuse subcommands with honest "not implemented" descriptions:
/// invoking them refuses loudly with the historical #1149 message
/// instead of args' generic unknown-subcommand error.
class SkinCommand extends Command<void> {
  final SkinPlugin plugin;

  final FileSystem _auditFileSystem;

  @override
  String get name => 'skin';

  @override
  String get description =>
      'Generate Skin UI widgets (zuraffa_ui) for entities; also hosts the '
      'runtime skin-contract auditor (skin kit | verify | drive, issue '
      '#1102/#1112)';

  @override
  String get invocation =>
      'zfa skin <layout> <Entity> [options]'
      ' | zfa skin ui.schema.export [--project-root <dir>]'
      ' [--schema-version <v>]'
      ' | zfa skin kit|verify|drive [options]';

  SkinCommand(this.plugin, {String? projectRoot, FileSystem? fileSystem})
    : _auditFileSystem = fileSystem ?? const DefaultFileSystem() {
    // Runtime skin-contract auditor trio (issue #1102/#1112) — same
    // subcommand surface `zfa skin kit|verify|drive` as before the
    // plugin rename; dispatched by args' subcommand machinery before
    // the generation grammar is ever consulted.
    addSubcommand(
      audit.SkinKitCommand(
        projectRoot: projectRoot,
        fileSystem: _auditFileSystem,
      ),
    );
    addSubcommand(
      audit.SkinVerifyCommand(
        projectRoot: projectRoot,
        fileSystem: _auditFileSystem,
      ),
    );
    addSubcommand(audit.SkinDriveCommand());

    // Generation grammar (spec 1276): one subcommand per implemented
    // layout. Issue #1149 (kill list — fix list): only implemented
    // layouts are registered; grid/table are hidden refuse subcommands.
    addSubcommand(_SkinGenerateSubcommand(plugin, 'list'));
    addSubcommand(_SkinGenerateSubcommand(plugin, 'form'));
    addSubcommand(_RefusedSkinLayoutSubcommand('grid'));
    addSubcommand(_RefusedSkinLayoutSubcommand('table'));

    // SPEC 917 / #904 (seed sites 4+5): the ui.schema.export capability
    // is advertised in the manifest and must be invocable from the CLI
    // it advertises itself through — as a real subcommand so the
    // manifest treaty gate resolves its parser.
    addSubcommand(_SkinUiSchemaExportSubcommand(plugin));
  }
}

/// `zfa skin <layout> <Entity>` — the generation grammar.
///
/// The plugin's own configSchema declares `layout` — buildContext's
/// schema merge reads it off argResults, so it must exist as an option
/// on the serving parser (`wasParsed` throws for schema keys the parser
/// does not define); the subcommand overrides `context.data['layout']`
/// with its own name after buildContext.
class _SkinGenerateSubcommand extends Command<void> {
  final SkinPlugin plugin;
  final String layout;

  _SkinGenerateSubcommand(this.plugin, this.layout) {
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
    argParser.addOption(
      'layout',
      help: 'UI layout type',
      // Issue #1149 (kill list — fix list): only implemented layouts are
      // allowed — grid/table were advertised but never implemented.
      allowed: ['list', 'form'],
      defaultsTo: layout,
    );
    // PluginManager.buildContext reads the standard PluginCommand flags
    // AND the core generation params off argResults; without them
    // `zfa skin <layout> <Entity>` died with "Could not find an option
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
  String get name => layout;

  @override
  String get description => 'Generate a Skin $layout widget for an entity';

  @override
  String get invocation => 'zfa skin $layout <Entity> [options]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Usage: zfa skin $layout <Entity> [options]');
      print('Available layouts: list, form');
      exitCode = ExitProtocol.usage;
      return;
    }
    final entityName = rest.first;

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

    // Override layout in context data (the subcommand IS the layout).
    context.data['layout'] = layout;

    try {
      print('🚀 Generating Skin $layout widget for $entityName...');
      final files = await manager.run(context, activePlugins);

      // Issue #996: `zfa skin <layout> <Entity>` is a standalone
      // invocation — it ships the same capability receipt as
      // `zfa di create` & co. (plugin `skin`, capability = layout).
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
}

/// Refuse subcommand for advertised-but-unimplemented layouts
/// (issue #1149). Listed in help with an honest "not implemented"
/// description — the invocation refuses loudly with the historical
/// message instead of args' generic unknown-subcommand error, and the
/// config schema (the manifest surface) advertises exactly the
/// implemented layouts {list, form}.
class _RefusedSkinLayoutSubcommand extends Command<void> {
  final String layout;

  _RefusedSkinLayoutSubcommand(this.layout);

  @override
  String get name => layout;

  @override
  String get description =>
      'Not implemented (issue #1149) — invoking it refuses loudly; '
      'implemented layouts: list, form';

  @override
  Future<void> run() async {
    print('❌ Usage: zfa skin <layout> <Entity> [options]');
    print(
      'Layout "$layout" is not implemented (issue #1149): the old '
      'generator silently emitted a list widget instead. Available '
      'layouts: list, form',
    );
    exitCode = ExitProtocol.usage;
  }
}

/// `zfa skin ui.schema.export` — the CLI surface of the `ui.schema.export`
/// capability (spec 024 FR-006). Honors --project-root and
/// --schema-version exactly as the capability inputSchema declares; a
/// real subcommand so `zfa manifest --verify` resolves the serving
/// parser mechanically (SPEC 917 / #904).
class _SkinUiSchemaExportSubcommand extends Command<void> {
  final SkinPlugin plugin;

  _SkinUiSchemaExportSubcommand(this.plugin) {
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
  String get name => 'ui.schema.export';

  @override
  String get description =>
      'Export the skin plugin UI component vocabulary as a versioned, '
      'diff-stable JSON Schema';

  @override
  String get invocation => 'zfa skin ui.schema.export [options]';

  @override
  Future<void> run() async {
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
