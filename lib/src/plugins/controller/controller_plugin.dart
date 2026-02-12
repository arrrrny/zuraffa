import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'builders/controller_class_builder.dart';

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
///   dryRun: false,
///   force: true,
///   verbose: false,
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class ControllerPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ControllerClassBuilder classBuilder;

  /// Creates a [ControllerPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param dryRun If true, files are not written.
  /// @param force If true, existing files are overwritten.
  /// @param verbose If true, logs progress to stdout.
  /// @param classBuilder Optional class builder override.
  ControllerPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ControllerClassBuilder? classBuilder,
  }) : classBuilder = classBuilder ?? const ControllerClassBuilder();

  /// @returns Plugin identifier.
  @override
  String get id => 'controller';

  /// @returns Plugin display name.
  @override
  String get name => 'Controller Plugin';

  /// @returns Plugin version string.
  @override
  String get version => '1.0.0';

  /// Generates controller files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated controller files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateController || config.generateVpc)) {
      return [];
    }
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final controllerName = '${entityName}Controller';
    final presenterName = '${entityName}Presenter';
    final stateName = '${entityName}State';
    final fileName = '${entitySnake}_controller.dart';

    final controllerDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(controllerDirPath, fileName);

    final withState = config.generateState;
    final methods = _buildMethods(config, entityName, entityCamel, withState);
    final imports = _buildImports(config, entitySnake, withState);

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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }
}
