import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/service_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/method_capability.dart';
import 'builders/service_interface_builder.dart';
import 'capabilities/create_service_capability.dart';

class ServicePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ServiceInterfaceBuilder interfaceBuilder;
  final MethodAppendBuilder methodAppendBuilder;

  ServicePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.interfaceBuilder = const ServiceInterfaceBuilder(),
    MethodAppendBuilder? methodAppendBuilder,
  }) : methodAppendBuilder =
           methodAppendBuilder ??
           MethodAppendBuilder(outputDir: outputDir, options: options);

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateServiceCapability(this),
    MethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'service',
    ),
  ];

  @override
  Command createCommand() => ServiceCommand(this);

  @override
  String get id => 'service';

  @override
  String get name => 'Service Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'service': {'type': 'string', 'description': 'Custom service name'},
      // Issue #978 (schema ≡ grammar): the service grammar is
      // params/returns/type/init (see ServiceCommand and the create
      // capability's inputSchema). configSchema is what JSON agents and
      // `zfa make` synthesize their contract from — before this map they
      // saw only `service` and the knobs were unreachable from make and
      // invisible to agents. Defaults mirror the command grammar
      // (ServiceCommand: params 'NoParams', returns 'void', type 'usecase',
      // init false).
      'params': {
        'type': 'string',
        'description':
            'Parameter type for the service method '
            '(e.g. String, MyParams)',
        'default': 'NoParams',
      },
      'returns': {
        'type': 'string',
        'description':
            'Return type for the service method '
            '(e.g. String, List<int>)',
        'default': 'void',
      },
      'type': {
        'type': 'string',
        'description': 'Service method type (sync, stream, completable)',
        'enum': ['sync', 'stream', 'completable', 'usecase'],
        'default': 'usecase',
      },
      'init': {
        'type': 'boolean',
        'description': 'Generate initialization and disposal methods',
        'default': false,
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final domain =
        context.get<String>('domain') ?? context.core.name.toLowerCase();

    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateService: true,
      service: context.get<String>('service'),
      // Issue #978 (make-triad consistency): mirror the usecase/repository
      // entity-methods default (['get', 'update', 'toggle']) so the service
      // interface lands on the ENTITY path with the same member surface
      // the generated usecases import and call. Before this default the
      // make triad produced a hollow `abstract class XService {}` on the
      // flat path while the usecases imported
      // domain/services/<domain>/<x>_service.dart and called
      // `_service.<method>(params)` — three internally-broken contracts.
      methods:
          context.data['methods']?.cast<String>() ??
          (context.get<bool>('no-entity') == true
              ? []
              : ['get', 'update', 'toggle']),
      domain: domain,
      noEntity: context.data['no-entity'] == true,
      // Issue #978 (schema ≡ grammar): the schema-mapped knobs are readable
      // from the make context (PluginManager.buildContext merges
      // configSchema properties into context.data).
      paramsType: context.data['params'],
      returnsType: context.data['returns'],
      useCaseType: context.get<String>('type') ?? 'usecase',
      generateInit: context.get<bool>('init') ?? false,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    // Issue #978 — the legacy silent no-op, killed.
    //
    // History: this method used to carry a "backward-compat" guard
    // (`!config.generateService && !config.revert` → return [] for
    // non-entity, non-custom, non-data configs). That guard was dead code
    // — `!isEntityBased && !isCustomUseCase` is unsatisfiable because the
    // two getters are exact complements (isCustomUseCase ≡ !isEntityBased)
    // — so it is removed. The LIVE silent path was the one below: no
    // resolvable service name (service == null && useService == false,
    // e.g. the service plugin active in make without a `--service <Name>`
    // value, or a direct generate() call with a plain entity config)
    // returned `[]` without a trace: no reason, no skip action, exit 0
    // upstream — the #769 false-success family. It is now a structured
    // skip: the reason is logged, a machine-actionable `--> fix:` line
    // names the invocation that would produce a service artifact, and the
    // empty return keeps the CLI zero-file guard (CapabilityCommand,
    // issue #769) armed to exit non-zero. A skip is never dressed up as
    // success at any layer.
    final serviceSnake = config.serviceSnake;
    if (serviceSnake == null) {
      final reason = config.useService
          ? 'no service name resolvable for "${config.name}"'
          : 'no service name was provided (service == null, useService == '
                'false) for "${config.name}"';
      print(
        '⚠️  Skipping service generation: $reason. The service plugin can '
        'only emit an interface when a service is named.\n'
        '--> fix: name the service explicitly — `zfa service create '
        '--name <ServiceName>` for a standalone interface, or `zfa make '
        '${config.name} --service <ServiceName>` for the full triad.',
      );
      return [];
    }
    final fileName = '${serviceSnake}_service.dart';
    final filePath = config.isEntityBased
        ? path.join(
            outputDir,
            'domain',
            'services',
            config.effectiveDomain,
            fileName,
          )
        : path.join(outputDir, 'domain', 'services', fileName);
    final content = interfaceBuilder.build(
      config,
      fileSystem: context?.fileSystem,
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'service',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: context?.fileSystem,
    );

    return [file];
  }
}
