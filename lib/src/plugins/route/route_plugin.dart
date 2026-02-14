import 'package:args/command_runner.dart';
import '../../commands/route_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/route_builder.dart';

class RoutePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final RouteBuilder routeBuilder;

  RoutePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    routeBuilder = RouteBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

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
      dryRun: config.dryRun,
      force: config.force,
      verbose: config.verbose,
    );
    return builder.generate(config);
  }
}
