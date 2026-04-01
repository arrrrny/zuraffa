import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/test_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/test_builder.dart';
import 'capabilities/create_test_capability.dart';

/// Manages unit test generation for domain and data layers.
class TestPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final TestBuilder testBuilder;
  final FileSystem fileSystem;

  TestPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(root: outputDir) {
    testBuilder = TestBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
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

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateTest && !config.revert) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = TestPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    final fs = context?.fileSystem ?? fileSystem;
    final builder = context != null
        ? TestBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
            discovery: context.discovery,
          )
        : testBuilder;

    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      final validMethods = [
        'get',
        'getList',
        'list',
        'create',
        'update',
        'delete',
        'watch',
        'watchList',
      ];
      for (final method in config.methods) {
        if (!validMethods.contains(method)) continue;
        files.add(await builder.generateForMethod(config, method));
      }
    }

    if (config.isOrchestrator) {
      files.add(await builder.generateOrchestrator(config));
    }

    if (config.isPolymorphic) {
      files.addAll(await builder.generatePolymorphic(config));
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      files.add(await builder.generateCustom(config));
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
    FileSystem? fs,
  }) async {
    final effectiveFs = fs ?? fileSystem;
    final analysis = await _analyzeUseCase(
      name,
      outputDir,
      domain,
      effectiveFs,
    );
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
    FileSystem fs,
  ) async {
    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    final useCaseSnake = StringUtils.camelToSnake(nameWithoutSuffix);
    final className = '${nameWithoutSuffix}UseCase';

    final domainDirPath = path.join(outputDir, 'domain', 'usecases', domain);
    if (await fs.exists(domainDirPath)) {
      final useCaseFile = path.join(
        domainDirPath,
        '${useCaseSnake}_usecase.dart',
      );

      if (await fs.exists(useCaseFile)) {
        final content = await fs.read(useCaseFile);
        return _parseUseCaseFile(content, className, domain);
      }
    }

    final usecasesDirPath = path.join(outputDir, 'domain', 'usecases');
    if (await fs.exists(usecasesDirPath)) {
      final items = await fs.list(usecasesDirPath);
      for (final item in items) {
        if (await fs.isDirectory(item)) {
          final foundDomain = path.basename(item);
          final useCaseFile = path.join(item, '${useCaseSnake}_usecase.dart');

          if (await fs.exists(useCaseFile)) {
            final content = await fs.read(useCaseFile);
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
