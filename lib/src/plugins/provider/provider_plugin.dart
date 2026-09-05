import 'package:args/command_runner.dart';
import '../../commands/provider_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../method_append/builders/inject_builder.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/inject_capability.dart';
import '../method_append/capabilities/method_capability.dart';
import '../method_append/capabilities/private_method_capability.dart';
import 'builders/provider_builder.dart';
import 'capabilities/create_provider_capability.dart';

/// Manages data provider generation for the data layer.
class ProviderPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final ProviderBuilder providerBuilder;
  final MethodAppendBuilder methodAppendBuilder;
  final InjectBuilder injectBuilder;

  ProviderPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MethodAppendBuilder? methodAppendBuilder,
    InjectBuilder? injectBuilder,
  }) : methodAppendBuilder =
           methodAppendBuilder ??
           MethodAppendBuilder(outputDir: outputDir, options: options),
       injectBuilder =
           injectBuilder ??
           InjectBuilder(outputDir: outputDir, options: options) {
    providerBuilder = ProviderBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateProviderCapability(this),
    MethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'provider',
    ),
    PrivateMethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'provider',
    ),
    InjectCapability(
      this,
      injectBuilder: injectBuilder,
      targetType: 'provider',
    ),
  ];

  @override
  List<String> get dependsOn => ['service'];

  @override
  Command createCommand() => ProviderCommand(this);

  @override
  String get id => 'provider';

  @override
  String get name => 'Provider Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      // Spec #979 (order 3, schema ≡ grammar): the provider grammar is
      // domain/params/returns/type/init/data — the same knobs the create
      // capability's inputSchema declares (what synthesizes
      // `zfa provider create --<knob>`). configSchema is what JSON agents
      // and `zfa make` synthesize their contract from, so every knob is
      // advertised here too. No params/returns defaults on purpose: the
      // interface-extraction path (the provider mirrors the Service
      // interface) is the live semantic (#768/#979) — a default would
      // force a phantom method onto every make-run provider.
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for the provider method',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for the provider method',
      },
      'type': {
        // Plain string here (NOT the enum): `zfa make` synthesizes one
        // shared --type option from the FIRST schema that declares it,
        // and the provider registers before graphql — an enum here would
        // reject graphql's legal values (query/mutation/...). The enum
        // contract lives on the provider-scoped
        // `zfa provider create --type` (the create inputSchema), where
        // no other plugin competes for the name.
        'type': 'string',
        'description':
            'Provider method type (sync, stream, completable, usecase)',
      },
      'init': {
        'type': 'boolean',
        'description': 'Generate initialization and disposal methods',
        'default': false,
      },
      'data': {
        'type': 'boolean',
        'description': 'Generate provider implementation',
        'default': true,
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
      generateData:
          context.data['provider'] == true || context.get<bool>('data') == true,
      service: context.data['service'],
      useService:
          context.data['use-service'] == true ||
          context.data['useService'] == true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
      // Spec #979 (order 3): the schema-mapped knobs are readable from the
      // make context (PluginManager.buildContext merges configSchema
      // properties into context.data) — the make flow and the
      // `zfa provider create` subcommand now drive the same grammar.
      // `type` is gated to the provider's legal values because the
      // make-level --type flag is SHARED context data (graphql passes
      // query/mutation through it) — a non-provider value must not
      // leak into _returnType.
      paramsType: context.data['params'],
      returnsType: context.data['returns'],
      useCaseType:
          const [
            'sync',
            'stream',
            'completable',
            'usecase',
          ].contains(context.data['type'])
          ? context.data['type'] as String
          : 'usecase',
      generateInit: context.get<bool>('init') ?? false,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.hasService || !config.generateData) {
      if (!config.revert) return [];
    }

    final builder = context != null
        ? ProviderBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : providerBuilder;

    final file = await builder.generate(config);
    return [file];
  }
}
