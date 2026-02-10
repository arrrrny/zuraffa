import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/builder/shared/spec_library.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/utils/file_utils.dart';

class AdvancedPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  AdvancedPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  @override
  String get id => 'advanced_example';

  @override
  String get name => 'Advanced Plugin Example';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final clazz = Class(
      (b) => b
        ..name = 'GeneratedGreeting'
        ..fields.add(
          Field(
            (f) => f
              ..name = 'message'
              ..type = refer('String')
              ..modifier = FieldModifier.final$,
          ),
        )
        ..constructors.add(
          Constructor(
            (c) => c
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'message'
                    ..toThis = true,
                ),
              ),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'greet'
              ..returns = refer('String')
              ..body = Code('return message;'),
          ),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [clazz],
        directives: [Directive.import('package:zuraffa/zuraffa.dart')],
      ),
    );

    final filePath = path.join(
      outputDir,
      'custom_plugin',
      'advanced_output.dart',
    );
    final file = await FileUtils.writeFile(
      filePath,
      content,
      'custom_plugin',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }
}
