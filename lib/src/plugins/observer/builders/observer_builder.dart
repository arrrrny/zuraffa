import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

/// Generates state observer classes.
class ObserverBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final FileSystem fileSystem;

  ObserverBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create();

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
              ..name = 'onDataCallback',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = onErrorType
              ..name = 'onErrorCallback',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = onCompleteType
              ..name = 'onDoneCallback',
          ),
        ])
        ..constructors.add(
          Constructor(
            (ctr) => ctr
              ..optionalParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'onDataCallback'
                    ..named = true
                    ..required = true
                    ..toThis = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'onErrorCallback'
                    ..named = true
                    ..required = true
                    ..toThis = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'onDoneCallback'
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
              ..name = 'onData'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'data'
                    ..type = refer(entityName),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('onDataCallback').call([refer('data')]).statement,
                  ),
              ),
          ),
          Method(
            (m) => m
              ..name = 'onError'
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
                    refer('onErrorCallback').call([refer('failure')]).statement,
                  ),
              ),
          ),
          Method(
            (m) => m
              ..name = 'onDone'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..body = Block(
                (b) => b
                  ..statements.add(refer('onDoneCallback').call([]).statement),
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
      fileSystem: fileSystem,
    );
  }
}
