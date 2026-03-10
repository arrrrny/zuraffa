import 'package:args/command_runner.dart';
import '../../commands/route_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/route_builder.dart';
import 'capabilities/create_route_capability.dart';

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
  List<ZuraffaCapability> get capabilities => [CreateRouteCapability(this)];

  @override
  Command createCommand() => RouteCommand(this);

  @override
  String get id => 'route';

  @override
  String get name => 'Route Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateRoute) {
      return [];
    }
    // Re-create builder with config flags if needed, or update builder to use config
    final builder = RouteBuilder(
      outputDir: config.outputDir,
      options: GeneratorOptions(
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      ),
    );
    return builder.generate(config);
  }
}
