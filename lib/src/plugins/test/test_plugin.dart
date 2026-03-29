import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/test_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/test_builder.dart';
import 'capabilities/create_test_capability.dart';

/// Manages unit test generation for domain and data layers.
///
/// Builds test classes for use cases, repositories, and providers using
/// mocktail and other testing utilities.
///
/// Example:
/// ```dart
/// final plugin = TestPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Auth'));
/// ```
class TestPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final TestBuilder testBuilder;

  TestPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    testBuilder = TestBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateTestCapability(this)];

  @override
  Command createCommand() => TestCommand(this);

  @override
  String get id => 'test';

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'testByDefault';

  @override
  JsonSchema get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateTest: true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      variants: context.data['variants']?.cast<String>().toList() ?? [],
      noEntity: context.data['no-entity'] == true,
      domain: context.data['domain'],
      repo: context.data['repo'],
      service: context.data['service'],
      generateData: context.data['data'] == true,
      generateDataSource: context.data['datasource'] == true,
      generateRepository: context.data['repository'] == true,
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateTest && !config.revert) {
      return [];
    }

    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      for (final method in config.methods) {
        files.add(await testBuilder.generateForMethod(config, method));
      }
    }

    if (config.isOrchestrator) {
      files.add(await testBuilder.generateOrchestrator(config));
    }

    if (config.isPolymorphic) {
      files.addAll(await testBuilder.generatePolymorphic(config));
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      files.add(await testBuilder.generateCustom(config));
    }

    return files;
  }

  /// Builds a [GeneratorConfig] by inspecting the existing usecase source.
  Future<GeneratorConfig?> buildConfigFromUseCase(
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
      r'final\s+(\w+UseCase)\s+_(\w+)',
    ).allMatches(content);
    final composedUsecases = usecaseMatches
        .map((m) {
          final className = m.group(1);
          if (className == null) return null;
          return className.endsWith('UseCase')
              ? className.substring(0, className.length - 7)
              : className;
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
