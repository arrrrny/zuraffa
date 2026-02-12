import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import '../core/builder/shared/spec_library.dart';
import '../core/generation/generation_context.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';

class ObserverGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  ObserverGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  ObserverGenerator.fromContext(GenerationContext context)
    : this(
        config: context.config,
        outputDir: context.outputDir,
        dryRun: context.dryRun,
        force: context.force,
        verbose: context.verbose,
      );

  Future<GeneratedFile> generate() async {
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

    final clazz = Class(
      (c) => c
        ..name = observerName
        ..extend = TypeReference((t) => t
          ..symbol = 'Observer'
          ..types.add(refer(entityName)))
        ..fields.addAll([
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer('void Function($entityName)')
              ..name = 'onNext',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer('void Function(AppFailure)')
              ..name = 'onError',
          ),
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer('void Function()')
              ..name = 'onComplete',
          ),
        ])
        ..constructors.add(
          Constructor(
            (ctr) => ctr
              ..optionalParameters.addAll([
                Parameter((p) => p
                  ..name = 'onNext'
                  ..named = true
                  ..required = true
                  ..toThis = true),
                Parameter((p) => p
                  ..name = 'onError'
                  ..named = true
                  ..required = true
                  ..toThis = true),
                Parameter((p) => p
                  ..name = 'onComplete'
                  ..named = true
                  ..required = true
                  ..toThis = true),
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
                Parameter((p) => p
                  ..name = 'value'
                  ..type = refer(entityName)),
              )
              ..body = Code('onNext(value);'),
          ),
          Method(
            (m) => m
              ..name = 'onFailure'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..requiredParameters.add(
                Parameter((p) => p
                  ..name = 'failure'
                  ..type = refer('AppFailure')),
              )
              ..body = Code('onError(failure);'),
          ),
          Method(
            (m) => m
              ..name = 'onDone'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..body = Code('onComplete();'),
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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
