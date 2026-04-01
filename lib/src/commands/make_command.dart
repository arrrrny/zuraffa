import 'dart:io';
import 'package:args/command_runner.dart';
import '../config/zfa_config.dart';
import '../cli/plugin_loader.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../models/generated_file.dart';

/// Command to run multiple plugins explicitly.
/// Usage: `zfa make <Name> <plugin1> <plugin2> ... [flags]`
/// Example: `zfa make User route di --force`
class MakeCommand extends Command<void> {
  final PluginRegistry registry;
  late final PluginManager manager;

  MakeCommand(this.registry) {
    final projectRoot = _findProjectRoot('lib/src');
    manager = PluginManager(
      registry: registry,
      config: ZfaConfig.load(projectRoot: projectRoot),
      pluginConfig: PluginConfig.load(projectRoot: projectRoot),
      projectRoot: projectRoot,
    );
    _addCoreOptions();
    _addPluginOptions();
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

  void _addCoreOptions() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/src',
    );
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
    argParser.addFlag(
      'init',
      abbr: 'i',
      negatable: false,
      help: 'Generate initialization and disposal methods',
    );
    argParser.addFlag(
      'zorphy',
      help:
          'Use Zorphy patterns (e.g., LocalePatch instead of Partial<Locale>)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'local',
      help: 'Generate local data source (instead of remote)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'remote',
      help: 'Generate remote data source',
      defaultsTo: true,
      negatable: true,
    );
    argParser.addFlag('cache', help: 'Enable caching', defaultsTo: false);
  }

  void _addPluginOptions() {
    final addedOptions = <String>{
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
    };

    for (final plugin in registry.plugins) {
      // Add a flag for the plugin itself to allow --no-<plugin> muting
      if (!addedOptions.contains(plugin.id)) {
        argParser.addFlag(
          plugin.id,
          help: 'Enable or disable ${plugin.name}',
          defaultsTo: true,
          negatable: true,
        );
        addedOptions.add(plugin.id);
      }

      // Add flags/options from plugin schema
      final schema = plugin.configSchema;
      if (schema.containsKey('properties')) {
        final properties = Map<String, dynamic>.from(
          schema['properties'] as Map,
        );
        for (final entry in properties.entries) {
          final key = entry.key;
          if (addedOptions.contains(key)) continue;

          final config = Map<String, dynamic>.from(entry.value as Map);
          final type = config['type'];
          final help = config['description'] ?? '';
          final def = config['default'];

          if (type == 'boolean') {
            argParser.addFlag(key, help: help, defaultsTo: def ?? false);
          } else if (type == 'string') {
            argParser.addOption(key, help: help, defaultsTo: def?.toString());
          } else if (type == 'array') {
            argParser.addMultiOption(
              key,
              help: help,
              defaultsTo: (def as List?)?.cast<String>(),
            );
          }
          addedOptions.add(key);
        }
      }
    }
  }

  @override
  String get name => 'make';

  @override
  String get description => 'Run multiple generator plugins explicitly.';

  @override
  String get invocation => 'zfa make <Name> <plugin1> <plugin2> ... [options]';

  /// Returns true if dry-run mode is enabled.
  bool get isDryRun => argResults?['dry-run'] == true;

  /// Returns true if force mode is enabled.
  bool get isForce => argResults?['force'] == true;

  /// Returns true if verbose logging is enabled.
  bool get isVerbose => argResults?['verbose'] == true;

  /// Returns true if revert mode is enabled.
  bool get isRevert => argResults?['revert'] == true;

  /// Returns the resolved output directory.
  String get outputDir => argResults?['output'] ?? 'lib/src';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print('Example: zfa make User route di');
      exit(1);
    }

    final entityName = rest[0];
    final explicitPluginIds = rest.skip(1).toList();

    // 1. Resolve active plugins (Config defaults + Explicit + Muting)
    final activePlugins = manager.resolveActivePlugins(
      explicitPluginIds: explicitPluginIds,
      argResults: argResults!,
    );

    if (activePlugins.isEmpty) {
      print('❌ No active plugins to run.');
      return;
    }

    // 2. Build context
    final context = manager.buildContext(
      name: entityName,
      argResults: argResults!,
      activePlugins: activePlugins,
    );

    if (context.core.verbose) {
      print(
        '🚀 Running plugins: ${activePlugins.map((p) => p.id).join(", ")} for $entityName...',
      );
    }

    // 3. Run lifecycle
    try {
      final files = await manager.run(context, activePlugins);
      _logSummary(files, context.core.verbose);
    } catch (e) {
      print('❌ Generation failed: $e');
      if (context.core.verbose) {
        rethrow;
      }
      exit(1);
    }

    print('✅ Done.');
  }

  void _logSummary(List<GeneratedFile> files, bool verbose) {
    if (files.isEmpty) {
      print('ℹ️  No files generated.');
      return;
    }

    final created = files.where((f) => f.action == 'created').length;
    final overwritten = files.where((f) => f.action == 'overwritten').length;
    final skipped = files.where((f) => f.action == 'skipped').length;
    final deleted = files.where((f) => f.action == 'deleted').length;

    print('\n✅ Generation complete:');
    if (created > 0) print('  ✨ Created: $created files');
    if (overwritten > 0) print('  📝 Overwritten: $overwritten files');
    if (skipped > 0) print('  ⏭ Skipped: $skipped files');
    if (deleted > 0) print('  🗑 Deleted: $deleted files');

    if (!verbose) {
      for (final file in files) {
        final prefix = switch (file.action) {
          'created' => '  ✨',
          'overwritten' => '  📝',
          'deleted' => '  🗑',
          _ => '  ⏭',
        };
        if (file.action != 'skipped') {
          print('$prefix ${file.path}');
        }
      }
    }
  }
}
