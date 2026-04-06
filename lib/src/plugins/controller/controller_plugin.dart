import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/controller_command.dart';
import '../../core/builder/patterns/common_patterns.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../models/parsed_usecase_info.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/controller_class_builder.dart';
import 'capabilities/create_controller_capability.dart';

part 'controller_plugin_bodies.dart';
part 'controller_plugin_methods.dart';
part 'controller_plugin_utils.dart';

/// Generates controller classes for the presentation layer.
class ControllerPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ControllerClassBuilder classBuilder;
  final FileSystem fileSystem;

  ControllerPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const ControllerClassBuilder(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateControllerCapability(this),
  ];

  @override
  String get id => 'controller';

  @override
  String get name => 'Controller Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => ControllerCommand(this);

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'vpc': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate full View/Presenter/Controller set',
      },
      'state': {
        'type': 'boolean',
        'default': true,
        'description': 'Generate state class for controller',
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
      generateController: true,
      generateVpcs: context.get<bool>('vpc') ?? context.data['vpcs'] == true,
      generateState:
          context.get<bool>('state') ?? context.data['state'] == true,
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.data['no-entity'] == true
              ? []
              : ['get', 'update', 'toggle']),
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateController && !config.generateVpcs && !config.revert) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = ControllerPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        classBuilder: classBuilder,
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    final fs = context?.fileSystem ?? fileSystem;

    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final controllerName = config.effectiveControllerName;
    final presenterName = config.effectivePresenterName;
    final stateName = config.effectiveStateName;
    final fileName = '${entitySnake}_controller.dart';

    final domainSnake = config.effectiveDomain;
    final controllerDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    );
    final filePath = path.join(controllerDirPath, fileName);

    final withState = config.generateState || config.customStateName != null;
    final noEntity = config.noEntity;

    // Now these methods are async and require fileSystem
    final methods = await _buildMethods(
      config,
      entityName,
      entityCamel,
      withState,
    );
    final imports = await _buildImports(config, domainSnake, withState);

    final content = classBuilder.build(
      ControllerClassSpec(
        className: controllerName,
        presenterName: presenterName,
        stateClassName: withState ? stateName : null,
        entityName: noEntity ? null : entityName,
        entityCamel: noEntity ? null : entityCamel,
        withState: withState,
        methods: methods,
        imports: imports,
      ),
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'controller',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
    return [file];
  }
}
