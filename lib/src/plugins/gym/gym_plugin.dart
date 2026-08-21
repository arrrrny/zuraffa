import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/gym_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/gym_builder.dart';
import 'capabilities/create_gym_capability.dart';

/// Generates GYM artifacts (warmup reps + graded exercises + gym.yaml) for
/// zuraffa apps/features.
///
/// A GYM is the inverse of a test suite: same rigor, opposite target. Where
/// a test suite proves the *code* is correct, a gym proves the *operator*
/// (human or agent) can actually drive that code under load. See
/// github.com/arrrrny/gym for the paradigm, github.com/arrrrny/miki for the
/// headless GYM runner that consumes the emitted `gym.yaml`.
///
/// This plugin mirrors [TestPlugin] exactly — same registration shape, same
/// lifecycle, same capability/command/builder split — so any tooling that
/// knows how to drive the test plugin can drive the gym plugin too.
class GymPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final GymBuilder gymBuilder;
  final FileSystem fileSystem;

  GymPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    gymBuilder = GymBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateGymCapability(this)];

  @override
  Command createCommand() => GymCommand(this);

  @override
  String get id => 'gym';

  @override
  String get name => 'Gym Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'gymByDefault';

  @override
  List<String> get runAfter => [
    'feature',
    'usecase',
    'repository',
    'service',
    'datasource',
    'provider',
    'view',
    'presenter',
    'controller',
    'di',
    'gql',
    'cache',
    'route',
    'shadcn',
    // Gym exercises reference the generated code AND its tests, so they must
    // run after the test plugin too.
    'test',
  ];

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
      // Default to the canonical CRUD method set used by the usecase /
      // repository / test plugins so the gym brief references real methods
      // the operator can actually drive.
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.get<bool>('no-entity') == true
              ? []
              : ['get', 'update', 'toggle']),
      domain: context.get<String>('domain'),
      noEntity: context.get<bool>('no-entity') ?? false,
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      generateGym: true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateGym && !config.revert) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = GymPlugin(
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
        ? GymBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
          )
        : gymBuilder;

    return builder.generateArtifact(config);
  }

  /// Builds a [GeneratorConfig] by inspecting the existing usecase source.
  ///
  /// Mirrors [TestPlugin.buildConfigFromUseCase] so the gym command can be
  /// pointed at an already-generated usecase and emit a gym artifact that
  /// references the real dependencies (repos, services, composed usecases).
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
    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    final useCaseSnake = StringUtils.camelToSnake(nameWithoutSuffix);
    final className = '${nameWithoutSuffix}UseCase';

    final domainDirPath = path.join(outputDir, 'domain', 'usecases', domain);
    if (await effectiveFs.exists(domainDirPath)) {
      final useCaseFile = path.join(
        domainDirPath,
        '${useCaseSnake}_usecase.dart',
      );
      if (await effectiveFs.exists(useCaseFile)) {
        final content = await effectiveFs.read(useCaseFile);
        return _configFromUseCaseContent(
          name: nameWithoutSuffix,
          outputDir: outputDir,
          domain: domain,
          content: content,
          className: className,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
      }
    }

    final usecasesDirPath = path.join(outputDir, 'domain', 'usecases');
    if (await effectiveFs.exists(usecasesDirPath)) {
      final items = await effectiveFs.list(usecasesDirPath);
      for (final item in items) {
        if (await effectiveFs.isDirectory(item)) {
          final foundDomain = path.basename(item);
          final useCaseFile = path.join(item, '${useCaseSnake}_usecase.dart');
          if (await effectiveFs.exists(useCaseFile)) {
            final content = await effectiveFs.read(useCaseFile);
            return _configFromUseCaseContent(
              name: nameWithoutSuffix,
              outputDir: outputDir,
              domain: foundDomain,
              content: content,
              className: className,
              dryRun: dryRun,
              force: force,
              verbose: verbose,
            );
          }
        }
      }
    }
    return null;
  }

  GeneratorConfig _configFromUseCaseContent({
    required String name,
    required String outputDir,
    required String domain,
    required String content,
    required String className,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) {
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
          final cn = m.group(1);
          if (cn == null) return null;
          return cn.endsWith('UseCase')
              ? cn.substring(0, cn.length - 7)
              : cn;
        })
        .whereType<String>()
        .toList();

    String? repo;
    for (final r in repos) {
      repo ??= '${r}Repository';
    }
    String? service;
    for (final s in services) {
      service ??= '${s}Service';
    }

    return GeneratorConfig(
      name: name,
      domain: domain,
      repo: repo,
      service: service,
      usecases: composedUsecases,
      generateGym: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      outputDir: outputDir,
    );
  }
}
