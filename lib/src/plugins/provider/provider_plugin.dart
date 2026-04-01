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
      'data': {
        'type': 'boolean',
        'default': true,
        'description': 'Generate provider implementation',
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
      generateData: context.get<bool>('data') ?? true,
      service: context.data['service'],
      useService:
          context.data['use-service'] == true ||
          context.data['useService'] == true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
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
