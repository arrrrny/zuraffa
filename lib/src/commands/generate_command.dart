import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../core/orchestration/plugin_orchestrator.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../cli/plugin_loader.dart';
import '../models/generator_config.dart';
import '../core/debug/artifact_saver.dart';

class GenerateCommand extends Command<void> {
  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate Clean Architecture code using presets or specific plugins';

  @override
  String get invocation => 'zfa generate <Name> [options]';

  GenerateCommand() {
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
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated methods: get,getList,create,update,delete,watch,watchList',
      defaultsTo: 'get,getList,create,update,delete',
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
      'vpc',
      help: 'Generate View + Presenter + Controller',
      defaultsTo: false,
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
    argParser.addFlag('cache', help: 'Enable caching', defaultsTo: false);
    argParser.addFlag(
      'zorphy',
      help: 'Use Zorphy-style typed patches',
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
    argParser.addFlag(
      'debug',
      negatable: false,
      help: 'Save artifacts to .zfa_debug',
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
    argParser.addOption(
      'usecases',
      help: 'Orchestrator: compose UseCases (comma-separated)',
    );
    argParser.addOption(
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
  }

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa generate <Name> [options]');
      print('\nPresets:');
      for (final preset in GenerationPreset.all) {
        print('  ${preset.name.padRight(12)} - ${preset.description}');
      }
      print('\nRun: zfa generate --help for more options');
      exit(1);
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final projectRoot = _findProjectRoot(outputDir);
    final pluginConfig = PluginConfig.load(projectRoot: projectRoot);
    final debug = argResults!['debug'] == true;
    final artifactSaver = DebugArtifactSaver(projectRoot: projectRoot);

    GeneratorConfig config;
    try {
      config = _buildConfig(name, pluginConfig);
      _validateConfig(config);
    } catch (e, stack) {
      if (argResults!['format'] == 'json') {
        print(
          jsonEncode({
            'success': false,
            'errors': [e.toString()],
          }),
        );
      } else {
        print('❌ $e');
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

    final registry = _buildRegistry(outputDir, pluginConfig);
    final orchestrator = PluginOrchestrator(
      registry: registry,
      logger: config.verbose ? print : null,
    );

    OrchestrationResult result;

    final presetName = argResults!['preset'] as String?;
    final pluginsStr = argResults!['plugins'] as String?;

    if (presetName != null) {
      result = await orchestrator.runPreset(
        presetName: presetName,
        config: config,
      );
    } else if (pluginsStr != null) {
      final plugins = pluginsStr.split(',').map((s) => s.trim()).toList();
      result = await orchestrator.runPlugins(plugins: plugins, config: config);
    } else {
      result = await orchestrator.runAllMatching(config);
    }

    if (debug) {
      await artifactSaver.saveOrchestration(
        config: config,
        result: result,
        args: argResults!.arguments.toList(),
      );
    }

    _printResult(result, config.verbose);

    if (!result.success) {
      exit(1);
    }
  }

  GeneratorConfig _buildConfig(String name, PluginConfig pluginConfig) {
    if (argResults!['from-stdin'] == true) {
      final input = stdin.readLineSync() ?? '';
      final json = jsonDecode(input) as Map<String, dynamic>;
      return GeneratorConfig.fromJson(json, name);
    } else if (argResults!['from-json'] != null) {
      final file = File(argResults!['from-json']);
      if (!file.existsSync()) {
        throw ArgumentError('JSON file not found: ${argResults!['from-json']}');
      }
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return GeneratorConfig.fromJson(json, name);
    }

    var methodsStr = argResults!['methods'] as String?;
    final methodsWasParsed = argResults!.wasParsed('methods');

    // If methods were not explicitly provided, but other flags indicate a custom usecase,
    // ignore the default methods value.
    if (!methodsWasParsed) {
      final isCustomUseCase = argResults!['domain'] != null ||
          argResults!['params'] != null ||
          argResults!['returns'] != null ||
          argResults!['usecases'] != null ||
          argResults!['variants'] != null ||
          argResults!['repo'] != null ||
          argResults!['service'] != null ||
          argResults!['type'] != null;

      if (isCustomUseCase) {
        methodsStr = null;
      }
    }
    final usecasesStr = argResults!['usecases'] as String?;
    final variantsStr = argResults!['variants'] as String?;

    final rawIdFieldType = argResults!['id-field-type'] as String;
    final validIdTypes = ['String', 'int', 'NoParams'];
    final idFieldType = validIdTypes.contains(rawIdFieldType)
        ? rawIdFieldType
        : throw ArgumentError(
            'Invalid --id-field-type: "$rawIdFieldType". '
            'Must be one of: ${validIdTypes.join(", ")}\n\n'
            '💡 Suggestions:\n'
            '   • Use --id-field-type=String,int,NoParams',
          );

    final queryFieldType =
        argResults!['query-field-type'] as String? ?? idFieldType;
    final idField = argResults!['id-field'] as String;
    final queryField = argResults!['query-field'] as String? ?? idField;

    final generateVpc =
        argResults!['vpc'] == true || argResults!['vpcs'] == true;
    final generateVpcs = argResults!['vpcs'] == true;
    final generatePc = argResults!['pc'] == true || argResults!['pcs'] == true;
    final generatePcs = argResults!['pcs'] == true;

    return GeneratorConfig(
      name: name,
      methods: methodsStr?.split(',').map((s) => s.trim()).toList() ?? [],
      repo: argResults!['repo'] as String?,
      service: argResults!['service'] as String?,
      usecases: usecasesStr?.split(',').map((s) => s.trim()).toList() ?? [],
      variants: variantsStr?.split(',').map((s) => s.trim()).toList() ?? [],
      domain: argResults!['domain'] as String?,
      repoMethod: argResults!['method'] as String?,
      serviceMethod: argResults!['service-method'] as String?,
      appendToExisting: argResults!['append'] == true,
      generateRepository: true,
      useCaseType: argResults!['type'] as String? ?? 'usecase',
      paramsType: argResults!['params'] as String?,
      returnsType: argResults!['returns'] as String?,
      idField: idField,
      idType: idFieldType,
      queryField: queryField,
      queryFieldType: queryFieldType,
      generateVpc: generateVpc,
      generateView: generateVpc || generateVpcs,
      generatePresenter:
          generateVpc || generateVpcs || generatePc || generatePcs,
      generateController:
          generateVpc || generateVpcs || generatePc || generatePcs,
      generateState:
          argResults!['state'] == true || generateVpcs || generatePcs,
      generateData: argResults!['data'] == true,
      generateDataSource: argResults!['datasource'] == true,
      generateInit: argResults!['init'] == true,
      useZorphy: argResults!['zorphy'] == true,
      generateTest: argResults!['test'] == true,
      enableCache: argResults!['cache'] == true,
      cachePolicy: argResults!['cache-policy'] as String? ?? 'daily',
      cacheStorage: argResults!['cache-storage'] as String?,
      ttlMinutes: argResults!['ttl'] != null
          ? int.tryParse(argResults!['ttl'])
          : null,
      generateMock: argResults!['mock'] == true,
      generateDi: argResults!['di'] == true,
      generateRoute: argResults!['route'] == true,
      generateGql: argResults!['gql'] == true,
      gqlReturns: argResults!['gql-returns'] as String?,
      gqlType: argResults!['gql-type'] as String?,
      gqlInputType: argResults!['gql-input-type'] as String?,
      gqlInputName: argResults!['gql-input-name'] as String?,
      gqlName: argResults!['gql-name'] as String?,
      outputDir: argResults!['output'] as String,
      dryRun: argResults!['dry-run'] == true,
      force: argResults!['force'] == true,
      verbose: argResults!['verbose'] == true,
    );
  }

  void _validateConfig(GeneratorConfig config) {
    if (config.isEntityBased) {
      if (config.domain != null) {
        throw ArgumentError(
          '--domain cannot be used with entity-based generation',
        );
      }
      if (config.repo != null) {
        throw ArgumentError(
          '--repo cannot be used with entity-based generation',
        );
      }
      if (config.service != null) {
        throw ArgumentError(
          '--service cannot be used with entity-based generation',
        );
      }
      if (config.usecases.isNotEmpty) {
        throw ArgumentError(
          '--usecases cannot be used with entity-based generation',
        );
      }
      if (config.variants.isNotEmpty) {
        throw ArgumentError(
          '--variants cannot be used with entity-based generation',
        );
      }
    }

    if (config.isCustomUseCase &&
        config.domain == null &&
        !config.usesCustomVpc) {
      throw ArgumentError('--domain is required for custom UseCases');
    }

    if (config.isOrchestrator &&
        (config.repo != null || config.service != null)) {
      throw ArgumentError('Cannot use --repo or --service with --usecases');
    }
  }

  PluginRegistry _buildRegistry(String outputDir, PluginConfig pluginConfig) {
    final loader = PluginLoader(
      outputDir: outputDir,
      dryRun: argResults!['dry-run'] == true,
      force: argResults!['force'] == true,
      verbose: argResults!['verbose'] == true,
      config: pluginConfig,
    );
    return loader.buildRegistry();
  }

  String _findProjectRoot(String outputDir) {
    var dir = Directory.current.path;
    while (dir != path.dirname(dir)) {
      if (File(path.join(dir, 'pubspec.yaml')).existsSync()) {
        return dir;
      }
      dir = path.dirname(dir);
    }
    return Directory.current.path;
  }

  void _printResult(OrchestrationResult result, bool verbose) {
    final format = argResults!['format'] as String;
    final quiet = argResults!['quiet'] == true;

    if (format == 'json') {
      print(
        jsonEncode({
          'success': result.success,
          'files': result.files.map((f) => f.toJson()).toList(),
          'errors': result.errors,
        }),
      );
      return;
    }

    if (!quiet) {
      if (result.success) {
        print('\n✅ Generated ${result.files.length} files:');
        for (final entry in result.filesByPlugin.entries) {
          final count = entry.value.where((f) => f.action == 'created').length;
          if (count > 0) {
            print('  ${entry.key}: $count files');
          }
        }
        if (verbose) {
          for (final file in result.files) {
            print('    ${file.path}');
          }
        }
      } else {
        print('\n❌ Generation failed:');
        for (final error in result.errors) {
          print('  • $error');
        }
      }
    }
  }
}
