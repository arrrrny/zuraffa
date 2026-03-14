import 'dart:io';

import 'package:args/command_runner.dart';
import '../config/zfa_config.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';

/// Command to run multiple plugins explicitly.
/// Usage: `zfa make <Name> <plugin1> <plugin2> ... [flags]`
/// Example: `zfa make User route di --force`
class MakeCommand extends Command<void> {
  final PluginRegistry registry;

  MakeCommand(this.registry) {
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
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    // Add other common flags as needed (domain, etc.)
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: ['future', 'stream', 'completable', 'sync', 'background'],
      defaultsTo: 'future',
      help: 'Execution strategy (default: future/fetch)',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain name (for usecases/DI)',
    );
    argParser.addOption(
      'repo',
      abbr: 'r',
      help: 'Repository name for custom usecases',
    );
    argParser.addOption(
      'service',
      abbr: 's',
      help: 'Service name for custom usecases',
    );
    argParser.addOption(
      'params',
      abbr: 'p',
      help: 'Parameter type for custom usecases (e.g., String, UserParams)',
    );
    argParser.addOption(
      'returns',
      abbr: 'R',
      help: 'Return type for custom usecases (e.g., void, User, List<User>)',
    );
    argParser.addOption(
      'usecases',
      abbr: 'u',
      help: 'Comma-separated list of usecases for orchestration',
    );
    argParser.addFlag(
      'use-mock',
      negatable: false,
      help: 'Use mock provider/datasource in DI registration',
    );
    argParser.addFlag(
      'init',
      abbr: 'i',
      negatable: false,
      help: 'Generate initialization and disposal methods',
    );
    argParser.addFlag(
      'use-service',
      negatable: false,
      help: 'Use service and provider instead of repository and datasource',
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
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print('Example: zfa make User route di');
      exit(1);
    }

    final entityName = args[0];
    final pluginNames = args.skip(1).toList();
    final userExplicitPlugins = pluginNames.toList();
    final isOrchestrator = argResults!['usecases'] != null;

    // Load project configuration
    final configData = ZfaConfig.load();
    if (configData != null) {
      if (configData.appendByDefault &&
          !pluginNames.contains('method_append')) {
        pluginNames.add('method_append');
      }
      // Only add data-layer defaults if not an orchestrator
      if (!isOrchestrator) {
        if (configData.mockByDefault && !pluginNames.contains('mock')) {
          pluginNames.add('mock');
        }
      }
      if (configData.diByDefault && !pluginNames.contains('di')) {
        pluginNames.add('di');
      }
    }

    // If it's an orchestrator, filter out data layer plugins unless explicitly requested
    if (isOrchestrator) {
      final dataLayerPlugins = {'datasource', 'repository', 'provider', 'mock'};
      pluginNames.removeWhere(
        (p) => dataLayerPlugins.contains(p) && !userExplicitPlugins.contains(p),
      );
    }

    if (pluginNames.isEmpty) {
      print('❌ No plugins specified.');
      print('Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print(
        'Available plugins: ${registry.plugins.map((p) => p.id).join(", ")}',
      );
      exit(1);
    }

    // Ensure method_append runs after datasource/repository/etc if they are in the list
    if (pluginNames.contains('method_append')) {
      pluginNames.remove('method_append');
      pluginNames.add('method_append');
    }
    // Ensure di runs after everything else
    if (pluginNames.contains('di')) {
      pluginNames.remove('di');
      pluginNames.add('di');
    }

    final outputDir = (argResults?['output'] as String?) ?? 'lib/src';
    final dryRun = argResults?['dry-run'] == true;
    final force = argResults?['force'] == true;
    final verbose = argResults?['verbose'] == true;
    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];
    final type = (argResults?['type'] as String?) ?? 'future';
    final domain = argResults?['domain'] as String?;
    final repo = argResults?['repo'] as String?;
    final service = argResults?['service'] as String?;
    final params = argResults?['params'] as String?;
    final returns = argResults?['returns'] as String?;
    final usecasesStr = argResults?['usecases'] as String?;
    final usecases = usecasesStr?.split(',').map((e) => e.trim()).toList();
    final useMockInDi = argResults!['use-mock'] == true;
    final generateInit = argResults!['init'] == true;
    final useService = argResults!['use-service'] == true;
    final useZorphy =
        argResults!['zorphy'] == true || (configData?.zorphyByDefault ?? true);
    final generateLocal = argResults!['local'] == true;
    final generateRemote = argResults!['remote'] != false;
    final enableCache = argResults!['cache'] == true;

    final isEntity = repo == null && service == null && usecases == null;

    // Create a base config that enables everything requested
    final config = GeneratorConfig(
      name: entityName,
      methods: isEntity ? methods : [], // Use CRUD methods for entity-based
      domain: domain,
      repo: repo,
      service: service,
      usecases: usecases ?? [],
      useCaseType: type,
      paramsType: params,
      returnsType: returns,
      useService: useService,
      appendToExisting: pluginNames.contains('method_append'),
      generateUseCase:
          pluginNames.contains('usecase') ||
          (pluginNames.contains('di') &&
              (repo != null || service != null || usecases != null)),
      generateService: pluginNames.contains('service'),
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      revert: isRevert,
      outputDir: outputDir,
      useMockInDi: useMockInDi,
      generateInit: generateInit,
      useZorphy: useZorphy,
      generateLocal: generateLocal,
      generateRemote: generateRemote,
      enableCache: enableCache || pluginNames.contains('cache'),
      // Map known plugins
      generateRoute: pluginNames.contains('route'),
      generateDi: pluginNames.contains('di'),
      generateView: pluginNames.contains('view'),
      generatePresenter: pluginNames.contains('presenter'),
      generateController: pluginNames.contains('controller'),
      generateRepository: pluginNames.contains('repository'),
      generateDataSource: pluginNames.contains('datasource'),
      generateData:
          pluginNames.contains('datasource') ||
          pluginNames.contains('repository') ||
          pluginNames.contains('provider'),
      generateState: pluginNames.contains('state'),
      generateTest: pluginNames.contains('test'),
      generateMock: pluginNames.contains('mock'),
      generateGql: pluginNames.contains('graphql'),
      generateObserver: pluginNames.contains('observer'),
    );

    print('🚀 Running plugins: ${pluginNames.join(", ")} for $entityName...');

    for (final pluginName in pluginNames) {
      final plugin = registry.getById(pluginName);
      if (plugin == null) {
        print('⚠️  Warning: Plugin "$pluginName" not found or not registered.');
        continue;
      }
      if (plugin is! FileGeneratorPlugin) {
        print(
          '⚠️  Warning: Plugin "$pluginName" does not support file generation.',
        );
        continue;
      }

      try {
        print('  Running ${plugin.name}...');
        final files = await plugin.generate(config);
        logSummary(files);
      } catch (e) {
        print('  ❌ Error running $pluginName: $e');
        if (verbose) {
          print(e);
        }
      }
    }

    print('✅ Done.');
  }

  /// Prints a summary of generated files.
  void logSummary(List<GeneratedFile> files) {
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

    // If not verbose, print generated file paths (verbose mode already prints from FileUtils)
    if (!isVerbose) {
      for (final file in files) {
        if (file.action == 'created') {
          print('  ✨ ${file.path}');
        } else if (file.action == 'overwritten') {
          print('  📝 ${file.path}');
        } else if (file.action == 'deleted') {
          print('  🗑 ${file.path}');
        }
      }
    }
  }
}
