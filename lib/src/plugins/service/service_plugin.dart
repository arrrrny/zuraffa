import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/service_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'builders/service_interface_builder.dart';

class ServicePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ServiceInterfaceBuilder interfaceBuilder;

  ServicePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ServiceInterfaceBuilder? interfaceBuilder,
  }) : interfaceBuilder = interfaceBuilder ?? const ServiceInterfaceBuilder();

  @override
  Command createCommand() => ServiceCommand(this);

  @override
  String get id => 'service';

  @override
  String get name => 'Service Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = ServicePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        interfaceBuilder: interfaceBuilder,
      );
      return delegator.generate(config);
    }

    if (!config.isCustomUseCase || !config.hasService) {
      return [];
    }
    final serviceSnake = config.serviceSnake;
    if (serviceSnake == null) {
      return [];
    }
    final fileName = '${serviceSnake}_service.dart';
    final filePath = path.join(outputDir, 'domain', 'services', fileName);
    final content = interfaceBuilder.build(config);

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'service',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );

    return [file];
  }
}
