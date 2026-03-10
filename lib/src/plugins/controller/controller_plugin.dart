import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/controller_command.dart';
import '../../core/constants/known_types.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/controller_class_builder.dart';
import 'capabilities/create_controller_capability.dart';

part 'controller_plugin_bodies.dart';
part 'controller_plugin_methods.dart';
part 'controller_plugin_utils.dart';

/// Generates controller classes for the presentation layer.
///
/// Builds controller classes that wire presenters and optional state for
/// entity screens and VPC flows.
///
/// Example:
/// ```dart
/// final plugin = ControllerPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class ControllerPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ControllerClassBuilder classBuilder;

  /// Creates a [ControllerPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param classBuilder Optional class builder override.
  ControllerPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const ControllerClassBuilder(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateControllerCapability(this),
  ];

  /// @returns Plugin identifier.
  @override
  String get id => 'controller';

  /// @returns Plugin display name.
  @override
  String get name => 'Controller Plugin';

  /// @returns Plugin version string.
  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => ControllerCommand(this);

  /// Generates controller files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated controller files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateController || config.generateVpcs)) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = ControllerPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
        ),
        classBuilder: classBuilder,
      );
      return delegator.generate(config);
    }

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
    final methods = _buildMethods(config, entityName, entityCamel, withState);
    final imports = _buildImports(config, domainSnake, withState);

    final content = classBuilder.build(
      ControllerClassSpec(
        className: controllerName,
        presenterName: presenterName,
        stateClassName: withState ? stateName : null,
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
    );
    return [file];
  }
}
