import 'package:args/command_runner.dart';
import '../../commands/route_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/route_builder.dart';
import 'capabilities/create_route_capability.dart';
import 'capabilities/custom_route_capability.dart';

/// Manages navigation route generation for Flutter applications.
///
/// Builds application-level route constants and entity-specific route builders,
/// ensuring type-safe navigation and route argument handling.
///
/// Example:
/// ```dart
/// final plugin = RoutePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class RoutePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final RouteBuilder routeBuilder;

  RoutePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    routeBuilder = RouteBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateRouteCapability(this),
    CustomRouteCapability(this),
  ];

  @override
  Command createCommand() => RouteCommand(this);

  @override
  String get id => 'route';

  @override
  String get name => 'Route Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'routeByDefault';

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
      generateRoute: true,
      generateVpcs: context.get<bool>('vpc') ?? context.data['vpcs'] == true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateRoute && !config.revert) {
      return [];
    }
    // Re-create builder with config flags if needed, or update builder to use config
    final builder = RouteBuilder(
      outputDir: config.outputDir,
      options: GeneratorOptions(
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        revert: config.revert,
      ),
      fileSystem: context?.fileSystem,
      discovery: context?.discovery,
    );
    return builder.generate(config);
  }
}
