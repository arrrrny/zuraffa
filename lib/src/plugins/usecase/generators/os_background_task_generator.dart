import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/usecase_class_builder.dart';

/// Generates OS background task-based use cases for the domain layer.
///
/// These use cases extend [OsBackgroundTask] and generate a static
/// `callbackHandler` suitable for workmanager registration, along
/// with a `register()` convenience method.
class OsBackgroundTaskGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  OsBackgroundTaskGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const UseCaseClassBuilder(),
    this.appendExecutor = const AppendExecutor(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final baseName = config.name.endsWith('UseCase')
        ? config.name.substring(0, config.name.length - 7)
        : config.name;
    final className = '${baseName}UseCase';
    final classSnake = StringUtils.camelToSnake(baseName);
    final fileName = '${classSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    // --- Imports ---
    final dependencyImports = <String>[];
    final dependencyFields = <Field>[];
    final constructorParams = <Parameter>[];

    if (config.hasService) {
      final serviceName = config.effectiveService;
      final serviceSnake = config.serviceSnake;
      if (serviceName == null || serviceSnake == null) {
        throw ArgumentError(
          'Service name must be specified via --service or config.service',
        );
      }
      dependencyImports.add('../../services/${serviceSnake}_service.dart');
      final serviceBaseName = serviceName.endsWith('Service')
          ? serviceName.substring(0, serviceName.length - 7)
          : serviceName;
      final serviceFieldName =
          '_${StringUtils.pascalToCamel(serviceBaseName)}Service';
      dependencyFields.add(
        Field(
          (b) => b
            ..name = serviceFieldName
            ..type = refer(serviceName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = serviceFieldName
            ..toThis = true,
        ),
      );
    } else if (config.hasRepo && config.effectiveRepos.isNotEmpty) {
      final repoName = config.effectiveRepos.first;
      final repoSnake = StringUtils.camelToSnake(
        repoName.replaceAll('Repository', ''),
      );
      dependencyImports.add('../../repositories/${repoSnake}_repository.dart');
      final repoBaseName = repoName.replaceAll('Repository', '');
      final repoFieldName =
          '_${StringUtils.pascalToCamel(repoBaseName)}Repository';
      dependencyFields.add(
        Field(
          (b) => b
            ..name = repoFieldName
            ..type = refer(repoName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = repoFieldName
            ..toThis = true,
        ),
      );
    }

    // --- Methods ---

    // 1. The `descriptor` getter: returns an OsBackgroundTaskDescriptor
    final descriptorGetter = Method(
      (b) => b
        ..name = 'descriptor'
        ..type = MethodType.getter
        ..returns = refer('OsBackgroundTaskDescriptor')
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Code(
          'return const OsBackgroundTaskDescriptor(\n'
          "  identifier: 'com.zuraffa.${classSnake}_task',\n"
          "  taskName: '$baseName',\n"
          ');',
        ),
    );

    // 2. The `execute` method: business logic to be called from handler
    final depField = dependencyFields.isNotEmpty ? dependencyFields.first.name : '';
    final executeBody = depField.isEmpty
        ? Block(
            (b) => b
              ..statements
                  .add(Code('// TODO: Implement OS background task logic'))
              ..statements.add(
                refer('UnimplementedError')
                    .call([literalString('Implement OS background task logic')])
                    .thrown
                    .statement,
              ),
          )
        : Block(
            (b) => b
              ..statements.add(
                refer(depField)
                    .property(config.hasService
                        ? config.getServiceMethodName()
                        : config.getRepoMethodName())
                    .call([refer('params')])
                    .awaited
                    .returned
                    .statement,
              ),
          );

    final executeMethod = Method(
      (b) => b
        ..name = 'execute'
        ..returns = refer('Future<$returnsType>')
        ..modifier = MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..annotations.add(CodeExpression(Code('override')))
        ..body = executeBody,
    );

    // 3. The `callbackHandler` static method (entry point for workmanager)
    final callbackHandler = Method(
      (b) => b
        ..name = 'callbackHandler'
        ..static = true
        ..returns = refer('Future<void>')
        ..annotations.add(CodeExpression(Code('@pragma(\'vm:entry-point\')')))
        ..body = Block(
          (b) => b
            ..statements.add(Code('// TODO: Wire up service/repository here'))
            ..statements.add(Code('// This runs in a background isolate (Android)'))
            ..statements.add(
              refer('UnimplementedError')
                  .call([
                    literalString(
                      'Implement callbackHandler — '
                      'this runs in the background isolate',
                    ),
                  ])
                  .thrown
                  .statement,
            ),
        ),
    );

    // --- Build class spec ---
    final spec = UseCaseClassSpec(
      className: className,
      baseClass: 'OsBackgroundTaskUseCase<$returnsType, $paramsType>',
      fields: dependencyFields,
      constructors: constructorParams.isEmpty
          ? const []
          : [
              Constructor(
                (b) => b..requiredParameters.addAll(constructorParams),
              ),
            ],
      methods: [descriptorGetter, executeMethod, callbackHandler],
      imports: [
        'package:zuraffa/zuraffa.dart',
        ...dependencyImports,
        ...CommonPatterns.entityImports(
          [paramsType, returnsType],
          config,
          depth: 3,
          includeDomain: false,
          fileSystem: fileSystem,
        ),
      ],
    );

    final content = classBuilder.build(spec);

    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      content: content,
    );
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required String content,
  }) async {
    if (config.revert) {
      return FileUtils.deleteFile(
        filePath,
        'usecase',
        dryRun: config.dryRun,
        verbose: config.verbose,
        fileSystem: fileSystem,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
