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

    final content = specLibrary.emitCode(
      '''
class $observerName extends Observer<$entityName> {
  final void Function($entityName) onNext;
  final void Function(AppFailure) onError;
  final void Function() onComplete;

  $observerName({
    required this.onNext,
    required this.onError,
    required this.onComplete,
  });

  @override
  void onNextValue($entityName value) => onNext(value);

  @override
  void onFailure(AppFailure failure) => onError(failure);

  @override
  void onDone() => onComplete();
}
''',
      directives: directives,
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
