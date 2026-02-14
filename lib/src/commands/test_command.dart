import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import '../models/generator_config.dart';
import '../models/generator_result.dart';
import 'base_plugin_command.dart';
import '../plugins/test/test_plugin.dart';
import '../utils/string_utils.dart';

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
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
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

    final analyzed = await _buildConfigFromUseCase(
      entityName,
      output,
      domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    final config = analyzed ??
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
    final entityName = argResults!.rest.first;
    final methodsValue = argResults!['methods'] as String;
    final methods = methodsValue.trim().isEmpty
        ? <String>[]
        : methodsValue.split(',').where((m) => m.trim().isNotEmpty).toList();
    final domain = argResults!['domain'] as String? ?? 'general';

    final analyzed = await _buildConfigFromUseCase(
      entityName,
      outputDir,
      domain,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
    );
    final config = analyzed ??
        GeneratorConfig(
          name: entityName,
          methods: methods,
          domain: domain,
          generateTest: true,
          dryRun: isDryRun,
          force: isForce,
          verbose: isVerbose,
          outputDir: outputDir,
        );

    final files = await plugin.generate(config);
    logSummary(files);
  }

  /// Builds a [GeneratorConfig] by inspecting the existing usecase source.
  Future<GeneratorConfig?> _buildConfigFromUseCase(
    String name,
    String outputDir,
    String domain, {
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final analysis = await _analyzeUseCase(name, outputDir, domain);
    if (analysis == null) {
      return null;
    }

    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    String? repo;
    String? service;
    final usecases = <String>[];

    for (final r in analysis['repos'] as List<String>) {
      final repoName = '${r}Repository';
      repo ??= repoName;
    }

    for (final s in analysis['services'] as List<String>) {
      final serviceName = '${s}Service';
      service ??= serviceName;
    }

    if (analysis['isOrchestrator'] == true) {
      usecases.addAll(analysis['usecases'] as List<String>);
    }

    return GeneratorConfig(
      name: nameWithoutSuffix,
      domain: analysis['domain'] as String,
      usecases: usecases,
      repo: repo,
      service: service,
      useCaseType: analysis['useCaseType'] as String,
      generateTest: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      outputDir: outputDir,
    );
  }

  /// Locates and parses the usecase file to infer dependencies.
  Future<Map<String, dynamic>?> _analyzeUseCase(
    String name,
    String outputDir,
    String domain,
  ) async {
    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    final useCaseSnake = StringUtils.camelToSnake(nameWithoutSuffix);
    final className = '${nameWithoutSuffix}UseCase';

    final domainDir = Directory(
      path.join(outputDir, 'domain', 'usecases', domain),
    );
    if (domainDir.existsSync()) {
      final useCaseFile = File(
        path.join(domainDir.path, '${useCaseSnake}_usecase.dart'),
      );

      if (useCaseFile.existsSync()) {
        final content = await useCaseFile.readAsString();
        return _parseUseCaseFile(content, className, domain);
      }
    }

    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      for (final dir in usecasesDir.listSync()) {
        if (dir is Directory) {
          final foundDomain = path.basename(dir.path);
          final useCaseFile = File(
            path.join(dir.path, '${useCaseSnake}_usecase.dart'),
          );

          if (useCaseFile.existsSync()) {
            final content = await useCaseFile.readAsString();
            return _parseUseCaseFile(content, className, foundDomain);
          }
        }
      }
    }

    return null;
  }

  /// Parses a usecase file to extract dependencies and type metadata.
  Map<String, dynamic> _parseUseCaseFile(
    String content,
    String className,
    String domain,
  ) {
    final repoMatches = RegExp(
      r'final\s+(\w+)Repository\s+(\w+)',
    ).allMatches(content);
    final repos = repoMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    final serviceMatches = RegExp(
      r'final\s+(\w+)Service\s+(\w+)',
    ).allMatches(content);
    final services = serviceMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    final usecaseMatches = RegExp(
      r'final\s+\w+UseCase\s+_(\w+)',
    ).allMatches(content);
    final composedUsecases = usecaseMatches
        .map((m) {
          final fieldName = m.group(1);
          if (fieldName == null) return null;
          final baseName = fieldName.startsWith('_')
              ? fieldName.substring(1)
              : fieldName;
          final classBase =
              baseName.substring(0, 1).toUpperCase() + baseName.substring(1);
          return classBase.endsWith('UseCase')
              ? classBase
              : '${classBase}UseCase';
        })
        .whereType<String>()
        .toList();

    final isOrchestrator =
        composedUsecases.isNotEmpty && repos.isEmpty && services.isEmpty;

    final useCaseType = _resolveUseCaseType(content);

    return {
      'className': className,
      'repos': repos,
      'services': services,
      'usecases': composedUsecases,
      'domain': domain,
      'isOrchestrator': isOrchestrator,
      'useCaseType': useCaseType,
    };
  }

  /// Determines usecase flavor based on inheritance in the source.
  String _resolveUseCaseType(String content) {
    if (content.contains('StreamUseCase')) {
      return 'stream';
    }
    if (content.contains('SyncUseCase')) {
      return 'sync';
    }
    if (content.contains('BackgroundUseCase')) {
      return 'background';
    }
    return 'usecase';
  }
}
