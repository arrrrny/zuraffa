import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

/// Generates state observer classes.
///
/// Builds Dart classes that implement the observer pattern for monitoring
/// stream results or state transitions in the domain layer.
///
/// Example:
/// ```dart
/// final builder = ObserverBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Auth'));
/// ```
class ObserverBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  ObserverBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final observerName = '${entityName}Observer';
    final fileName = '${entitySnake}_observer.dart';
    final filePath = path.join(
      outputDir,
      'domain',
      'usecases',
      entitySnake,
      fileName,
    );

    final directives = [
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import('../../entities/$entitySnake/$entitySnake.dart'),
    ];

    final onNextType = FunctionType(
      (f) => f
        ..returnType = refer('void')
        ..requiredParameters.add(refer(entityName)),
    );
    final onErrorType = FunctionType(
      (f) => f
        ..returnType = refer('void')
        ..requiredParameters.add(refer('AppFailure')),
    );
    final onCompleteType = FunctionType((f) => f..returnType = refer('void'));

    final clazz = Class(
      (c) => c
        ..name = observerName
        ..extend = TypeReference(
          (t) => t
            ..symbol = 'Observer'
            ..types.add(refer(entityName)),
        )
        ..fields.addAll([
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = onNextType
              ..name = 'onNext',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = onErrorType
              ..name = 'onError',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = onCompleteType
              ..name = 'onComplete',
          ),
        ])
        ..constructors.add(
          Constructor(
            (ctr) => ctr
              ..optionalParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'onNext'
                    ..named = true
                    ..required = true
                    ..toThis = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'onError'
                    ..named = true
                    ..required = true
                    ..toThis = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'onComplete'
                    ..named = true
                    ..required = true
                    ..toThis = true,
                ),
              ]),
          ),
        )
        ..methods.addAll([
          Method(
            (m) => m
              ..name = 'onNextValue'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'value'
                    ..type = refer(entityName),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('onNext').call([refer('value')]).statement,
                  ),
              ),
          ),
          Method(
            (m) => m
              ..name = 'onFailure'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'failure'
                    ..type = refer('AppFailure'),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('onError').call([refer('failure')]).statement,
                  ),
              ),
          ),
          Method(
            (m) => m
              ..name = 'onDone'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..body = Block(
                (b) =>
                    b..statements.add(refer('onComplete').call([]).statement),
              ),
          ),
        ]),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'observer',
      force: config.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }
}
