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

class ControllerPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ControllerClassBuilder classBuilder;

  ControllerPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ControllerClassBuilder? classBuilder,
  }) : classBuilder = classBuilder ?? const ControllerClassBuilder();

  @override
  String get id => 'controller';

  @override
  String get name => 'Controller Plugin';

  @override
  String get version => '1.0.0';

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
