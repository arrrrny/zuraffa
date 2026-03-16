import 'package:args/command_runner.dart';
import '../../commands/provider_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
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
///
/// Builds provider implementation classes that connect domain services
/// to external data sources or APIs.
///
/// Example:
/// ```dart
/// final plugin = ProviderPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Auth'));
/// ```
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
  Command createCommand() => ProviderCommand(this);

  @override
  String get id => 'provider';

  @override
  String get name => 'Provider Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = ProviderPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
      return delegator.generate(config);
    }

    if (!config.hasService || !config.generateData) {
      return [];
    }

    final file = await providerBuilder.generate(config);
    return [file];
  }
}
