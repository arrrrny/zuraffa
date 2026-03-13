import 'dart:io';
import 'package:args/args.dart';

import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../models/generator_result.dart';
import 'base_plugin_command.dart';
import '../plugins/test/test_plugin.dart';
import '../plugins/test/capabilities/create_test_capability.dart';

/// CLI command that generates tests for existing use cases.
///
/// Supports analyzing existing usecase files to infer repositories, services,
/// and orchestrator dependencies when present.
class TestCommand extends PluginCommand {
  @override
  final TestPlugin plugin;

  /// Creates a command bound to the provided [plugin].
  TestCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: '',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder for custom usecases',
      defaultsTo: 'general',
    );
  }

  @override
  /// Command identifier used by the CLI registry.
  String get name => 'test';

  @override
  /// Short description shown in help output.
  String get description => 'Generate Tests';

  /// Executes the command for the provided argument list.
  ///
  /// Returns a [GeneratorResult] instead of exiting when
  /// [exitOnCompletion] is false.
  Future<GeneratorResult> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      print('❌ Usage: zfa test <Name> [options]');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing arguments'],
        nextSteps: [],
      );
    }

    if (args[0] == '--help' || args[0] == '-h') {
      if (exitOnCompletion) exit(0);
      return GeneratorResult(
        name: 'help',
        success: true,
        files: [],
        errors: [],
        nextSteps: [],
      );
    }

    final entityName = args[0];
    if (entityName.startsWith('--')) {
      print('❌ Missing name');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing name'],
        nextSteps: [],
      );
    }

    final ArgResults results;
    try {
      results = argParser.parse(args.skip(1).toList());
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: [e.message],
        nextSteps: [],
      );
    }

    final methodsValue = results['methods'] as String;
    final methods = methodsValue.trim().isEmpty
        ? <String>[]
        : methodsValue.split(',').where((m) => m.trim().isNotEmpty).toList();
    final domain = results['domain'] as String? ?? 'general';
    final output = results['output'] as String? ?? 'lib/src';
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;

    final analyzed = await plugin.buildConfigFromUseCase(
      entityName,
      output,
      domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    final config =
        analyzed ??
        GeneratorConfig(
          name: entityName,
          methods: methods,
          domain: domain,
          generateTest: true,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
          outputDir: output,
        );

    try {
      final files = await plugin.generate(config);
      return GeneratorResult(
        name: entityName,
        success: true,
        files: files,
        errors: [],
        nextSteps: [],
      );
    } catch (e) {
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: entityName,
        success: false,
        files: [],
        errors: [e.toString()],
        nextSteps: [],
      );
    }
  }

  @override
  /// Runs the command using parsed CLI args.
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa test <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final methodsValue = (argResults?['methods'] as String?) ?? '';
    final methods = methodsValue.trim().isEmpty
        ? <String>[]
        : methodsValue.split(',').where((m) => m.trim().isNotEmpty).toList();
    final domain = (argResults?['domain'] as String?) ?? 'general';

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateTestCapability)
            as CreateTestCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'domain': domain,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate test');
    }
  }
}
