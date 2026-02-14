import 'dart:io';

import 'package:args/command_runner.dart';
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
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    // Add other common flags as needed (domain, etc.)
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain name (for usecases/DI)',
    );
  }

  @override
  String get name => 'make';

  @override
  String get description => 'Run multiple generator plugins explicitly.';

  @override
  String get invocation => 'zfa make <Name> <plugin1> <plugin2> ... [options]';

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

    if (pluginNames.isEmpty) {
      print('❌ No plugins specified.');
      print('Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print(
        'Available plugins: ${registry.plugins.map((p) => p.id).join(", ")}',
      );
      exit(1);
    }

    final outputDir = argResults!['output'] as String;
    final dryRun = argResults!['dry-run'] == true;
    final force = argResults!['force'] == true;
    final verbose = argResults!['verbose'] == true;
    final methods = (argResults!['methods'] as String).split(',');
    final domain = argResults!['domain'] as String?;

    // Create a base config that enables everything requested
    // Note: GeneratorConfig uses booleans like generateRoute, generateDi.
    // We map plugin names to these booleans.
    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      domain: domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      outputDir: outputDir,
      // Map known plugins
      generateRoute: pluginNames.contains('route'),
      generateDi: pluginNames.contains('di'),
      generateView: pluginNames.contains('view'),
      generatePresenter: pluginNames.contains('presenter'),
      generateController: pluginNames.contains('controller'),
      generateRepository: pluginNames.contains('repository'),
      generateDataSource: pluginNames.contains('datasource'),
      generateState: pluginNames.contains('state'),
      generateTest: pluginNames.contains('test'),
      enableCache: pluginNames.contains('cache'),
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

  void logSummary(List<GeneratedFile> files) {
    if (files.isEmpty) {
      print('ℹ️  No files generated.');
      return;
    }

    final created = files.where((f) => f.action == 'created').length;
    final overwritten = files.where((f) => f.action == 'overwritten').length;
    final skipped = files.where((f) => f.action == 'skipped').length;
    final deleted = files.where((f) => f.action == 'deleted').length;

    if (created > 0) print('  ✨ Created: $created files');
    if (overwritten > 0) print('  📝 Overwritten: $overwritten files');
    if (skipped > 0) print('  ⏭ Skipped: $skipped files');
    if (deleted > 0) print('  🗑 Deleted: $deleted files');

    // If not verbose, print generated file paths (verbose mode already prints from FileUtils)
    if (argResults?['verbose'] != true) {
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
