import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/service_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'builders/service_interface_builder.dart';
import 'capabilities/create_service_capability.dart';

class ServicePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ServiceInterfaceBuilder interfaceBuilder;

  ServicePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.interfaceBuilder = const ServiceInterfaceBuilder(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [CreateServiceCapability(this)];

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
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = ServicePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        interfaceBuilder: interfaceBuilder,
      );
      return delegator.generate(config);
    }

    // Skip service generation if not a custom usecase or no service specified
    if (!config.isCustomUseCase || !config.hasService) {
      return [];
    }

    // Skip service generation in append mode - MethodAppendPlugin handles service updates
    // When appending methods to existing services, MethodAppendPlugin is responsible for
    // updating the service interface to avoid conflicts and ensure proper method merging
    if (config.appendToExisting) {
      if (config.verbose) {
        print(
          'ServicePlugin: Skipping service generation in append mode. '
          'MethodAppendPlugin will handle service interface updates.',
        );
      }
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
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );

    return [file];
  }
}
