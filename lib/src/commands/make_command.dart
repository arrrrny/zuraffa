import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  static const String fixedOutputDir = 'lib/src';
  static const Set<String> _ignoredJsonOptionKeys = {
    'domainRoot',
    'domain-root',
    'domain_root',
    'domainOutput',
    'domain-output',
    'domain_output',
    'entityOutput',
    'entity-output',
    'entity_output',
    'output',
    'output-dir',
    'output_dir',
    'useZorphy',
    'zorphy',
  };

  final PluginRegistry registry;
  late final PluginManager manager;

  MakeCommand(this.registry) {
    final projectRoot = _findProjectRoot();
    manager = PluginManager(
      registry: registry,
      config: ZfaConfig.load(projectRoot: projectRoot),
      pluginConfig: PluginConfig.load(projectRoot: projectRoot),
      projectRoot: projectRoot,
    );
    _addCoreOptions();
    _addPluginOptions();
  }

  String _findProjectRoot() {
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
      help:
          'Output directory for generated files (fixed to lib/src in v5; custom values are ignored)',
      defaultsTo: fixedOutputDir,
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
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
    argParser.addOption(
      'from-json',
      abbr: 'j',
      help: 'JSON configuration file',
    );
    argParser.addFlag(
      'from-stdin',
      negatable: false,
      help: 'Read JSON configuration from stdin',
    );
    argParser.addOption('preset', help: 'Generation preset to expand');
    argParser.addMultiOption('with', help: 'Additional plugins or aliases');
    argParser.addMultiOption('without', help: 'Plugins or aliases to exclude');
    argParser.addFlag(
      'plan',
      negatable: false,
      help: 'Print the normalized execution plan and exit',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help: 'Explain the normalized execution plan and exit',
    );

    argParser.addMultiOption('methods', help: 'Entity methods to generate');
    argParser.addMultiOption(
      'usecases',
      help: 'UseCases to inject into presenter/controller',
    );
    argParser.addMultiOption(
      'variants',
      help: 'Polymorphic variants to generate',
    );
    argParser.addOption('domain', help: 'Domain subfolder');
    argParser.addOption('repo', help: 'Repository to inject');
    argParser.addOption('service', help: 'Service to inject');
    argParser.addOption('id-field', help: 'ID field name', defaultsTo: 'id');
    argParser.addOption(
      'id-field-type',
      help: 'ID field type',
      defaultsTo: 'String',
    );
    argParser.addOption(
      'query-field',
      help: 'Query field name',
      defaultsTo: 'id',
    );
    argParser.addOption('query-field-type', help: 'Query field type');
    argParser.addFlag('no-entity', negatable: false, help: 'Skip entity');
    argParser.addFlag('vpc', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('vpcs', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('state', negatable: false, help: 'Generate state class');
    argParser.addFlag('data', negatable: false, help: 'Generate data layer');
    argParser.addFlag(
      'datasource',
      negatable: false,
      help: 'Generate data source',
    );
    argParser.addFlag('cache', negatable: false, help: 'Enable caching');
    argParser.addFlag('route', negatable: false, help: 'Generate route');
    argParser.addFlag('mock', negatable: false, help: 'Generate mock data');
    argParser.addFlag('test', negatable: false, help: 'Generate tests');
    argParser.addFlag(
      'append',
      negatable: false,
      help: 'Append to existing repo/service',
    );
  }

  void _addPluginOptions() {
    final addedOptions = <String>{
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
      'format',
      'from-json',
      'from-stdin',
      'preset',
      'with',
      'without',
      'plan',
      'explain',
      'methods',
      'usecases',
      'variants',
      'domain',
      'repo',
      'service',
      'id-field',
      'id-field-type',
      'query-field',
      'query-field-type',
      'no-entity',
      'vpc',
      'vpcs',
      'state',
      'data',
      'datasource',
      'cache',
      'route',
      'mock',
      'test',
      'append',
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
          } else if (type == 'string' ||
              type == 'integer' ||
              type == 'number') {
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
  String get outputDir => fixedOutputDir;

  @override
  Future<void> run() async {
    final jsonConfig = await _loadJsonConfig();
    final rest = argResults!.rest;

    if (rest.isEmpty && jsonConfig == null) {
      print('❌ Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print('Example: zfa make User route di');
      exit(1);
    }

    final entityName = rest.isNotEmpty
        ? rest.first
        : (jsonConfig?['name']?.toString() ?? '');
    if (entityName.isEmpty) {
      print('❌ Missing required feature/entity name.');
      exit(1);
    }

    final explicitPluginIds = rest.skip(1).toList();
    final normalizedOptions = _normalizedOptions(jsonConfig);
    final plan = manager.resolvePlan(
      name: entityName,
      explicitPluginIds: explicitPluginIds,
      argResults: argResults!,
      options: normalizedOptions,
    );

    if (argResults?['plan'] == true || argResults?['explain'] == true) {
      _printPlan(plan);
      return;
    }

    final activePlugins = plan.activePlugins;
    if (activePlugins.isEmpty) {
      print('❌ No active plugins to run.');
      return;
    }

    final context = manager.buildContext(
      name: entityName,
      argResults: argResults!,
      activePlugins: activePlugins,
      overrideOutputDir: fixedOutputDir,
    );
    context.data.addAll(normalizedOptions);

    if (context.core.verbose) {
      print(
        '🚀 Running plugins: ${activePlugins.map((p) => p.id).join(", ")} for $entityName...',
      );
    }

    try {
      final files = await manager.run(context, activePlugins);
      _logSummary(files, context.core.verbose, plan: plan);
    } catch (e) {
      print('❌ Generation failed: $e');
      if (context.core.verbose) {
        rethrow;
      }
      exit(1);
    }

    if (argResults?['format'] != 'json') {
      print('✅ Done.');
    }
  }

  Future<Map<String, dynamic>?> _loadJsonConfig() async {
    try {
      if (argResults?['from-stdin'] == true) {
        final input = await stdin.transform(utf8.decoder).join();
        if (input.trim().isEmpty) return null;
        return jsonDecode(input) as Map<String, dynamic>;
      }

      final fromJson = argResults?['from-json'] as String?;
      if (fromJson == null || fromJson.isEmpty) {
        return null;
      }

      final file = File(fromJson);
      if (!file.existsSync()) {
        throw StateError('JSON file not found: $fromJson');
      }
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error parsing JSON input: $e');
      exit(1);
    }
  }

  Map<String, dynamic> _normalizedOptions(Map<String, dynamic>? jsonConfig) {
    final normalized = <String, dynamic>{};
    if (jsonConfig == null) {
      return normalized;
    }

    jsonConfig.forEach((key, value) {
      final normalizedKey = key.replaceAll('_', '-');
      if (_ignoredJsonOptionKeys.contains(key) ||
          _ignoredJsonOptionKeys.contains(normalizedKey)) {
        return;
      }
      normalized[normalizedKey] = value;
      normalized[key] = value;
    });

    return normalized;
  }

  void _printPlan(dynamic plan) {
    if (argResults?['format'] == 'json') {
      print(jsonEncode({'success': true, 'plan': plan.toJson()}));
      return;
    }

    print('🧭 Normalized plan for ${plan.name}:');
    if (plan.preset != null) {
      print('  Preset: ${plan.preset}');
    }
    print('  Requested: ${plan.requestedPluginIds.join(', ')}');
    print('  Resolved: ${plan.pluginIds.join(', ')}');
    if (plan.warnings.isNotEmpty) {
      print('  Warnings:');
      for (final warning in plan.warnings) {
        print('    - $warning');
      }
    }
  }

  void _logSummary(
    List<GeneratedFile> files,
    bool verbose, {
    required dynamic plan,
  }) {
    if (argResults?['format'] == 'json') {
      print(
        jsonEncode({
          'success': true,
          'plan': plan.toJson(),
          'files': files.map((file) => file.toJson()).toList(),
          'warnings': plan.warnings,
        }),
      );
      return;
    }

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
