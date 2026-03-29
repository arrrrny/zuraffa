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
      methods: context.data['methods']?.cast<String>() ?? [],
      domain: domain,
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateService && !config.revert) {
      // For backward compatibility with direct plugin calls in tests and legacy orchestrator
      if (!config.isEntityBased &&
          !config.isCustomUseCase &&
          !config.generateData) {
        return [];
      }
    }
    final serviceSnake = config.serviceSnake;
    if (serviceSnake == null) {
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
