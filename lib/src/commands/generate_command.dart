import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../config/zfa_config.dart';
import '../cli/plugin_loader.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plugin_context.dart';
import '../models/generated_file.dart';
import '../core/debug/artifact_saver.dart';

class GenerateCommand extends Command<void> {
  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate Clean Architecture code using presets or specific plugins';

  @override
  String get invocation => 'zfa generate <Name> [OPTIONS]';

  late final PluginManager manager;

  GenerateCommand() {
    final projectRoot = _findProjectRoot('lib/src');
    manager = PluginManager(
      registry: PluginRegistry.instance,
      config: ZfaConfig.load(projectRoot: projectRoot),
      pluginConfig: PluginConfig.load(projectRoot: projectRoot),
      projectRoot: projectRoot,
    );
    _addStaticOptions();
    _addPluginOptions();
  }

  void _addStaticOptions() {
    argParser.addOption(
      'preset',
      abbr: 'p',
      help:
          'Generation preset: entity-crud, vpc, vpc-state, full-stack, data-layer',
    );
    argParser.addOption(
      'plugins',
      help:
          'Comma-separated list of plugins to run (e.g., repository,usecase,view)',
    );
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated methods: get,getList,create,update,delete,watch,watchList',
      defaultsTo: ['get', 'getList', 'create', 'update', 'delete'],
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
      defaultsTo: 'lib/src',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder for custom usecases',
    );
    argParser.addOption(
      'id-field-type',
      help: 'ID field type (String, int, NoParams)',
      defaultsTo: 'String',
    );
    argParser.addOption('id-field', help: 'ID field name', defaultsTo: 'id');
    argParser.addOption('query-field-type', help: 'Query field type');
    argParser.addOption('query-field', help: 'Query field name');
    argParser.addMultiOption(
      'fields',
      abbr: 'F',
      help: 'Entity fields "name:type,name:type"',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview without writing files',
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
      help: 'Detailed output',
    );
    argParser.addFlag(
      'debug',
      negatable: false,
      help: 'Save artifacts to .zfa_debug',
    );
    argParser.addFlag(
      'vpcs',
      help: 'Generate View + Presenter + Controller + State',
      defaultsTo: false,
    );
    argParser.addFlag(
      'pc',
      help: 'Generate Presenter + Controller only',
      defaultsTo: false,
    );
    argParser.addFlag(
      'pcs',
      help: 'Generate Presenter + Controller + State',
      defaultsTo: false,
    );
    argParser.addFlag(
      'state',
      help: 'Generate State object',
      defaultsTo: false,
    );
    argParser.addFlag(
      'use-service',
      help: 'Use service and provider instead of repository and datasource',
      defaultsTo: false,
    );
    argParser.addFlag(
      'test',
      abbr: 't',
      help: 'Generate unit tests',
      defaultsTo: false,
    );
    argParser.addFlag(
      'di',
      help: 'Generate dependency injection',
      defaultsTo: false,
    );
    argParser.addFlag(
      'data',
      help: 'Generate data repository + data source',
      defaultsTo: false,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate data source only',
      defaultsTo: false,
    );
    argParser.addFlag(
      'local',
      help: 'Generate local data source (instead of remote)',
      defaultsTo: false,
    );
    argParser.addFlag('cache', help: 'Enable caching', defaultsTo: false);
    argParser.addFlag(
      'zorphy',
      help: 'Use Zorphy-style typed patches',
      defaultsTo: false,
    );
    argParser.addFlag(
      'no-entity',
      help: 'Do not treat the name as an entity',
      defaultsTo: false,
    );
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
    argParser.addFlag(
      'quiet',
      abbr: 'q',
      help: 'Minimal output',
      defaultsTo: false,
    );
    argParser.addOption(
      'from-json',
      abbr: 'j',
      help: 'JSON configuration file',
    );
    argParser.addFlag(
      'from-stdin',
      negatable: false,
      help: 'Read JSON from stdin',
    );
    argParser.addOption(
      'repo',
      help: 'Repository to inject (for custom UseCase)',
    );
    argParser.addOption(
      'service',
      help: 'Service to inject (for custom UseCase)',
    );
    argParser.addMultiOption(
      'usecases',
      help: 'Orchestrator: compose UseCases (comma-separated)',
    );
    argParser.addMultiOption(
      'variants',
      help: 'Polymorphic: generate variants (comma-separated)',
    );
    argParser.addOption(
      'type',
      help: 'UseCase type: usecase, stream, background, completable',
    );
    argParser.addOption('params', help: 'Params type (default: NoParams)');
    argParser.addOption('returns', help: 'Return type (default: void)');
    argParser.addFlag(
      'append',
      negatable: false,
      help: 'Append to existing repository/service',
    );
    argParser.addFlag(
      'init',
      negatable: false,
      help: 'Generate initialize method',
    );
    argParser.addFlag(
      'route',
      negatable: false,
      help: 'Generate go_router routing files',
    );
    argParser.addFlag(
      'mock',
      negatable: false,
      help: 'Generate mock data source',
    );
    argParser.addFlag(
      'use-mock',
      negatable: false,
      help: 'Use mock provider/datasource in DI registration',
    );
    argParser.addFlag(
      'gql',
      negatable: false,
      help: 'Generate GraphQL queries/mutations',
    );
    argParser.addOption(
      'gql-returns',
      help: 'GraphQL return fields (comma-separated)',
    );
    argParser.addOption(
      'gql-type',
      help: 'GraphQL operation type: query, mutation, subscription',
    );
    argParser.addOption('gql-input-type', help: 'GraphQL input type name');
    argParser.addOption('gql-input-name', help: 'GraphQL input parameter name');
    argParser.addOption('gql-name', help: 'GraphQL operation name');
    argParser.addOption(
      'cache-policy',
      help: 'Cache policy: daily, restart, ttl',
    );
    argParser.addOption(
      'cache-storage',
      help: 'Local storage hint: hive, sqlite, shared_preferences',
    );
    argParser.addOption('ttl', help: 'TTL duration in minutes');
    argParser.addOption('method', help: 'Dependency method name');
    argParser.addOption('service-method', help: 'Service method name');
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generation (undo created files)',
    );
  }

  void _addPluginOptions() {
    final addedOptions = argParser.options.keys.toSet();

    for (final plugin in manager.registry.plugins) {
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
  Future<void> run() async {
    final args = argResults!.rest;
    final isJsonInput =
        argResults!['from-json'] != null || argResults!['from-stdin'] == true;

    if (args.isEmpty && !isJsonInput) {
      stderr.writeln('❌ Usage: zfa generate <Name> [options]');
      stderr.writeln('\nRun: zfa generate --help for more options');
      exit(1);
    }

    final outputDir = argResults!['output'] as String;
    final projectRoot = _findProjectRoot(outputDir);
    final artifactSaver = DebugArtifactSaver(projectRoot: projectRoot);
    final debug = argResults!['debug'] == true;

    // Load configuration from JSON or stdin if provided
    Map<String, dynamic>? jsonConfig;
    String name = args.isNotEmpty ? args.first : '';

    try {
      if (argResults!['from-stdin'] == true) {
        final input = stdin.readLineSync() ?? '';
        jsonConfig = jsonDecode(input) as Map<String, dynamic>;
        if (name.isEmpty) name = jsonConfig['name'] ?? '';
      } else if (argResults!['from-json'] != null) {
        final file = File(argResults!['from-json']);
        if (!file.existsSync()) {
          stderr.writeln('❌ JSON file not found: ${argResults!['from-json']}');
          exit(1);
        }
        jsonConfig =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        if (name.isEmpty) name = jsonConfig['name'] ?? '';
      }
    } catch (e) {
      stderr.writeln('❌ Error parsing JSON input: $e');
      exit(1);
    }

    // Resolve active plugins based on flags, presets and JSON config
    final explicitPlugins = _resolvePluginSelection(jsonConfig);

    final activePlugins = manager.resolveActivePlugins(
      explicitPluginIds: explicitPlugins,
      argResults: argResults!,
    );

    if (activePlugins.isEmpty) {
      stderr.writeln('❌ No plugins selected for generation.');
      exit(1);
    }

    final context = manager.buildContext(
      name: name,
      argResults: argResults!,
      activePlugins: activePlugins,
    );

    // Merge JSON config into context data if provided
    if (jsonConfig != null) {
      jsonConfig.forEach((key, value) {
        final normalizedKey = key.replaceAll('_', '-');
        context.data[normalizedKey] = value;
        context.data[key] = value;
      });
    }

    // Validation for custom usecase requirements
    final methods =
        (context.data['methods'] as List?)?.cast<String>().toList() ?? [];
    final noEntity = context.data['no-entity'] == true;
    final isCustomUseCase = methods.isEmpty || noEntity;
    if (isCustomUseCase &&
        context.data['domain'] == null &&
        context.data['vpc'] != true &&
        context.data['vpcs'] != true) {
      stderr.writeln('❌ Error: --domain is required for custom UseCases');
      stderr.writeln(
        '   Usage: zfa generate <Name> --domain <domain_name> [options]',
      );
      exit(1);
    }

    // Strict validation for ID field type
    final idFieldType =
        (jsonConfig?['id_field_type'] ??
                jsonConfig?['id_type'] ??
                argResults!['id-field-type'])
            as String;
    final validIdTypes = ['String', 'int', 'NoParams'];
    if (!validIdTypes.contains(idFieldType)) {
      final error =
          'Invalid --id-field-type: "$idFieldType". '
          'Must be one of: ${validIdTypes.join(", ")}\n\n'
          '💡 Suggestions:\n'
          '   • Use --id-field-type=String,int,NoParams';
      if (argResults!['format'] == 'json') {
        print(
          jsonEncode({
            'success': false,
            'errors': [error],
          }),
        );
      } else {
        stderr.writeln('❌ $error');
      }
      if (debug) {
        await artifactSaver.saveSimple(
          args: argResults!.arguments.toList(),
          error: error,
          stackTrace: StackTrace.current.toString(),
        );
      }
      exit(1);
    }

    try {
      final files = await manager.run(context, activePlugins);

      if (debug) {
        await artifactSaver.saveOrchestration(
          config: context.data,
          result: files,
          args: argResults!.arguments.toList(),
        );
      }

      _printResult(files, context);
    } on ArgumentError catch (e) {
      if (argResults!['format'] == 'json') {
        print(
          jsonEncode({
            'success': false,
            'errors': [e.message],
          }),
        );
      } else {
        stderr.writeln('❌ Invalid argument: ${e.message}');
      }
      exit(1);
    } on StateError catch (e) {
      if (argResults!['format'] == 'json') {
        print(
          jsonEncode({
            'success': false,
            'errors': [e.message],
          }),
        );
      } else {
        stderr.writeln('❌ Error: ${e.message}');
      }
      exit(1);
    } catch (e, stack) {
      if (argResults!['format'] == 'json') {
        print(
          jsonEncode({
            'success': false,
            'errors': [e.toString()],
          }),
        );
      } else {
        stderr.writeln('❌ Generation failed: $e');
      }

      if (debug) {
        await artifactSaver.saveSimple(
          args: argResults!.arguments.toList(),
          error: e.toString(),
          stackTrace: stack.toString(),
        );
      }
      exit(1);
    }
  }

  String _findProjectRoot(String outputDir) {
    var dir = Directory.current.path;
    try {
      while (dir != path.dirname(dir)) {
        if (File(path.join(dir, 'pubspec.yaml')).existsSync()) {
          return dir;
        }
        dir = path.dirname(dir);
      }
    } catch (e) {
      // If we cannot get current working directory or access paths, return current directory
      return Directory.current.path;
    }
    return Directory.current.path;
  }

  List<String> _resolvePluginSelection(Map<String, dynamic>? jsonConfig) {
    final selection = <String>{};

    // Helper to check if a flag is true either in argResults or jsonConfig
    bool isTrue(String key, {String? jsonKey}) {
      final jKey = jsonKey ?? key;

      // If it matches a plugin ID, we only consider it "true" for SELECTION if
      // it was explicitly parsed as true, or provided in JSON.
      // Plugins are enabled by default, but shouldn't count as explicit selection
      // unless the user actually typed it.
      final isPluginId = manager.registry.plugins.any((p) => p.id == key);
      if (isPluginId) {
        final wasParsed = argResults!.wasParsed(key);
        final isExplicitlyOn = wasParsed && argResults![key] == true;
        final inJson = jsonConfig != null && jsonConfig[jKey] == true;
        return isExplicitlyOn || inJson;
      }

      return argResults![key] == true ||
          (jsonConfig != null && jsonConfig[jKey] == true);
    }

    // 1. Explicit plugins from string
    final pluginsStr = argResults!['plugins'] as String?;
    if (pluginsStr != null) {
      selection.addAll(pluginsStr.split(',').map((s) => s.trim()));
    }
    if (jsonConfig != null && jsonConfig['plugins'] is List) {
      selection.addAll((jsonConfig['plugins'] as List).cast<String>());
    }

    // 2. Individual flags / JSON properties
    if (isTrue('vpcs', jsonKey: 'vpcs') || isTrue('vpcs', jsonKey: 'vpc')) {
      selection.addAll(['view', 'presenter', 'controller', 'state']);
    }
    if (isTrue('pc')) {
      selection.addAll(['presenter', 'controller']);
    }
    if (isTrue('pcs')) {
      selection.addAll(['presenter', 'controller', 'state']);
    }
    if (isTrue('state')) selection.add('state');
    if (isTrue('test')) selection.add('test');
    if (isTrue('di')) selection.add('di');
    if (isTrue('data') || isTrue('datasource')) {
      selection.addAll(['repository', 'datasource']);
    }
    if (isTrue('route')) selection.add('route');
    if (isTrue('mock')) selection.add('mock');
    if (isTrue('gql')) selection.add('gql');
    if (isTrue('graphql')) selection.add('graphql');
    if (isTrue('cache')) selection.add('cache');
    if (isTrue('append')) selection.add('method_append');

    // 3. Methods check (implicit plugins)
    final methodsWasParsed =
        argResults!.wasParsed('methods') ||
        (jsonConfig != null && jsonConfig.containsKey('methods'));

    final methodsList = (argResults!['methods'] as List<String>? ?? [])
        .where((m) => m.isNotEmpty)
        .toList();
    final noEntity =
        argResults!['no-entity'] == true ||
        (jsonConfig != null && jsonConfig['no_entity'] == true);

    if (methodsWasParsed && selection.isEmpty) {
      selection.add('usecase');
      if (methodsList.isNotEmpty && !noEntity) {
        selection.add('repository');
      }
    }

    // Default if nothing specified: assume entity-crud (usecase + repository)
    if (selection.isEmpty && argResults!['preset'] == null) {
      selection.addAll(['usecase', 'repository']);
    }

    return selection.toList();
  }

  void _printResult(List<GeneratedFile> files, PluginContext context) {
    final format = argResults!['format'] as String;
    final quiet = argResults!['quiet'] == true;

    if (format == 'json') {
      print(
        jsonEncode({
          'success': true,
          'files': files.map((f) => f.toJson()).toList(),
          'errors': [],
        }),
      );
      return;
    }

    if (!quiet) {
      if (context.core.revert) {
        print('\n🗑️  Reverted ${files.length} files:');
      } else {
        print('\n✅ Generated ${files.length} files:');
      }

      if (files.isEmpty && context.core.verbose) {
        print('    (No files were changed)');
      }

      for (final file in files) {
        final icon = switch (file.action) {
          'created' => '✨',
          'overwritten' => '📝',
          'deleted' => '🗑 ',
          _ => '⏭ ',
        };
        if (file.action != 'skipped' || context.core.verbose) {
          print('    $icon ${file.path}');
        }
      }
    }
  }
}
