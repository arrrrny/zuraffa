import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../../../core/generator_options.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';

/// Builds the `<Feature>FeaturePlugin` orchestrator file.
class ModuleOrchestratorBuilder {
  final String outputDir;
  final GeneratorOptions options;

  const ModuleOrchestratorBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final featureName = config.name;
    final className = '${_pascal(featureName)}FeaturePlugin';
    final fileName = '${_snake(featureName)}_feature_plugin.dart';
    final filePath = '$outputDir/plugin/$fileName';

    final emitter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );

    final library = Library(
      (b) => b
        ..directives.add(Directive.import('package:zuraffa/zuraffa.dart'))
        ..body.add(
          Class(
            (c) => c
              ..name = className
              ..extend = refer('ZuraffaPlugin')
              ..methods.addAll([
                Method(
                  (m) => m
                    ..annotations.add(refer('override'))
                    ..name = 'pluginId'
                    ..type = MethodType.getter
                    ..returns = refer('String')
                    ..body = Code("return '${_snake(featureName)}';"),
                ),
                Method(
                  (m) => m
                    ..annotations.add(refer('override'))
                    ..name = 'registerDependencies'
                    ..returns = refer('void')
                    ..requiredParameters.add(
                      Parameter(
                        (p) => p
                          ..name = 'di'
                          ..type = refer('ZuraffaDIContainer'),
                      ),
                    )
                    ..body = Code('// TODO: register dependencies.\n'),
                ),
                Method(
                  (m) => m
                    ..annotations.add(refer('override'))
                    ..name = 'routes'
                    ..type = MethodType.getter
                    ..returns = refer('Map<String, ZuraffaRouteBuilder>')
                    ..body = Code('return const {};'),
                ),
              ]),
          ),
        ),
    );

    final raw = library.accept(DartEmitter()).toString();
    final code = emitter.format(raw);

    final file = await FileUtils.writeFile(
      filePath,
      code,
      'module',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
    return [file];
  }

  String _pascal(String name) => name
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();

  String _snake(String name) => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .replaceFirst(RegExp(r'^_'), '');
}
