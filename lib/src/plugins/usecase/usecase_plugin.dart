import 'package:args/command_runner.dart';
import '../../commands/usecase_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/create_usecase_capability.dart';
import 'generators/custom_usecase_generator.dart';
import 'generators/entity_usecase_generator.dart';
import 'generators/os_background_task_generator.dart';
import 'generators/stream_usecase_generator.dart';
import 'usecase_verdicts.dart';

/// Manages use case generation for the domain layer.
class UseCasePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  late final EntityUseCaseGenerator entityGenerator;
  late final CustomUseCaseGenerator customGenerator;
  late final StreamUseCaseGenerator streamGenerator;
  late final OsBackgroundTaskGenerator osBackgroundGenerator;

  UseCasePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    entityGenerator = EntityUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
    customGenerator = CustomUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
    streamGenerator = StreamUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
    osBackgroundGenerator = OsBackgroundTaskGenerator(
      outputDir: outputDir,
      options: options,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateUseCaseCapability(this)];

  @override
  Command createCommand() => UseCaseCommand(this);

  @override
  String get id => 'usecase';

  @override
  String get name => 'UseCase Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Methods to generate (get, create, etc.)',
      },
      'type': {
        'type': 'string',
        'enum': [
          'usecase',
          'stream',
          'background',
          'os_background',
          'completable',
        ],
        'default': 'usecase',
      },
      'domain': {'type': 'string', 'description': 'Domain folder name'},
      'repo': {'type': 'string', 'description': 'Repository name'},
      'service': {'type': 'string', 'description': 'Service name'},
      'params': {'type': 'string', 'description': 'Parameter type'},
      'returns': {'type': 'string', 'description': 'Return type'},
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'UseCases for orchestrator pattern',
      },
      'variants': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Variants for polymorphic pattern',
      },
      'no-entity': {
        'type': 'boolean',
        'default': false,
        'description': 'Disable entity-based generation',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.get<bool>('no-entity') == true
              ? []
              // Spec #972 FR-5: toggle left the silent default vocabulary —
              // it is generated only when explicitly requested via
              // --methods (and only when the source-interface guard can
              // see it declared).
              : ['get', 'update']),
      useCaseType: context.get<String>('type') ?? 'usecase',
      domain: context.get<String>('domain'),
      repo: context.get<String>('repo'),
      service: context.get<String>('service'),
      paramsType: context.get<String>('params'),
      returnsType: context.get<String>('returns'),
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      variants: context.data['variants']?.cast<String>().toList() ?? [],
      noEntity: context.get<bool>('no-entity') ?? false,
      // #294: read id-field / query-field from the CLI/MakeCommand-resolved
      // context so generators don't hardcode `EntityFields.id` for
      // entities whose id field is e.g. `depotId`.
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      generateUseCase: true,
      generateData: context.data['data'] == true,
      generateRepository: context.data['repository'] == true,
    );

    // Spec #972 FR-4: collect the same-plan interface expectations the
    // guard records on fail-open, so `zfa make`'s post-pass can verify the
    // responsible plugin (repository/service) declared the requested
    // methods before the plan is declared successful.
    final expectations = <UseCaseInterfaceExpectation>[];
    final files = await generate(
      config,
      context: context,
      onInterfaceExpectation: expectations.add,
    );
    if (expectations.isNotEmpty) {
      context.data['usecase_interface_expectations'] = expectations
          .map((e) => e.toJson())
          .toList();
    }
    return files;
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
    void Function(UseCaseInterfaceExpectation expectation)?
    onInterfaceExpectation,
    bool quiet = false,
  }) async {
    final report = await generateWithReport(
      config,
      context: context,
      onInterfaceExpectation: onInterfaceExpectation,
      quiet: quiet,
    );
    return report.files;
  }

  /// Spec #972 API: [generate] with the full machine report (per-method
  /// verdicts + guard outcome) for entity-based runs. Custom-usecase
  /// paths (orchestrator/polymorphic/stream/custom) carry no per-method
  /// vocabulary — the report wraps their files with empty verdicts.
  Future<UsecaseGenerationReport> generateWithReport(
    GeneratorConfig config, {
    PluginContext? context,
    void Function(UseCaseInterfaceExpectation expectation)?
    onInterfaceExpectation,
    bool quiet = false,
  }) async {
    if (!config.generateUseCase && !config.revert) {
      if (!config.isEntityBased &&
          !config.isCustomUseCase &&
          !config.isOrchestrator &&
          !config.isPolymorphic) {
        return const UsecaseGenerationReport(
          files: [],
          verdicts: [],
          interfaceAbsent: false,
          guardReasonCodes: {},
        );
      }
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = UseCasePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
      return delegator.generateWithReport(
        config,
        context: context,
        onInterfaceExpectation: onInterfaceExpectation,
        quiet: quiet,
      );
    }

    final entityGen = context != null
        ? EntityUseCaseGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : entityGenerator;

    final customGen = context != null
        ? CustomUseCaseGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : customGenerator;

    final streamGen = context != null
        ? StreamUseCaseGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : streamGenerator;

    final osBackgroundGen = context != null
        ? OsBackgroundTaskGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : osBackgroundGenerator;

    if (config.isEntityBased) {
      return entityGen.generateWithVerdicts(
        config,
        onInterfaceExpectation: onInterfaceExpectation,
        quiet: quiet,
      );
    }
    if (config.isPolymorphic) {
      final files = await customGen.generatePolymorphic(config);
      return UsecaseGenerationReport(
        files: files,
        verdicts: const [],
        interfaceAbsent: false,
        guardReasonCodes: const {},
      );
    }
    if (config.isOrchestrator) {
      final files = [await customGen.generateOrchestrator(config)];
      return UsecaseGenerationReport(
        files: files,
        verdicts: const [],
        interfaceAbsent: false,
        guardReasonCodes: const {},
      );
    }
    if (config.useCaseType == 'stream') {
      final files = [await streamGen.generate(config)];
      return UsecaseGenerationReport(
        files: files,
        verdicts: const [],
        interfaceAbsent: false,
        guardReasonCodes: const {},
      );
    }
    if (config.useCaseType == 'os_background') {
      final files = [await osBackgroundGen.generate(config)];
      return UsecaseGenerationReport(
        files: files,
        verdicts: const [],
        interfaceAbsent: false,
        guardReasonCodes: const {},
      );
    }
    if (config.isCustomUseCase) {
      final files = [await customGen.generate(config)];
      return UsecaseGenerationReport(
        files: files,
        verdicts: const [],
        interfaceAbsent: false,
        guardReasonCodes: const {},
      );
    }
    return const UsecaseGenerationReport(
      files: [],
      verdicts: [],
      interfaceAbsent: false,
      guardReasonCodes: {},
    );
  }
}
