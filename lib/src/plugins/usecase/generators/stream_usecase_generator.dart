import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/usecase_class_builder.dart';

/// Generates stream-based use cases for the domain layer.
///
/// Builds use case classes that return data streams, typically used for
/// real-time updates and reactive features.
///
/// Example:
/// ```dart
/// final generator = StreamUseCaseGenerator(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await generator.generate(GeneratorConfig(name: 'Chat'));
/// ```
class StreamUseCaseGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;

  StreamUseCaseGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const UseCaseClassBuilder(),
    this.appendExecutor = const AppendExecutor(),
  });

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
    final baseClass = 'StreamUseCase<$returnsType, $paramsType>';

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

    final executeBody = dependencyFields.isNotEmpty
        ? Block(
            (b) => b
              ..statements.add(
                refer(dependencyFields.first.name)
                    .property(_methodName(config))
                    .call([refer('params')])
                    .returned
                    .statement,
              ),
          )
        : Block(
            (b) => b
              ..statements.add(Code('// TODO: Implement logic'))
              ..statements.add(
                refer('UnimplementedError').call([]).thrown.statement,
              ),
          );

    final executeMethod = Method(
      (b) => b
        ..name = 'execute'
        ..returns = refer('Stream<$returnsType>')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        )
        ..annotations.add(CodeExpression(Code('override')))
        ..body = executeBody,
    );

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: dependencyFields,
      constructors: constructorParams.isEmpty
          ? const []
          : [
              Constructor(
                (b) => b..requiredParameters.addAll(constructorParams),
              ),
            ],
      methods: [executeMethod],
      imports: [
        'package:zuraffa/zuraffa.dart',
        ...dependencyImports,
        ...CommonPatterns.entityImports(
          [paramsType, returnsType],
          config,
          depth: 2,
          includeDomain: false,
        ),
      ],
    );

    final content = classBuilder.build(spec);
    final methodSource =
        '@override\nStream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {\n  $executeBody\n}';
    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      methodSource: methodSource,
      content: content,
    );
  }

  String _methodName(GeneratorConfig config) {
    return config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required String methodSource,
    required String content,
  }) async {
    if (config.revert) {
      if (config.appendToExisting) {
        if (config.verbose) {
          print('  ⚠️ Cannot revert append operation for $filePath');
        }
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
        );
      }
      return FileUtils.deleteFile(
        filePath,
        'usecase',
        dryRun: config.dryRun,
        verbose: config.verbose,
      );
    }

    if (config.appendToExisting && File(filePath).existsSync()) {
      if (config.force) {
        return FileUtils.writeFile(
          filePath,
          content,
          'usecase',
          force: true,
          dryRun: config.dryRun,
          verbose: config.verbose,
        );
      }

      final existing = await File(filePath).readAsString();
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: existing,
          className: className,
          memberSource: methodSource,
        ),
      );
      if (!result.changed) {
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
          content: result.source,
        );
      }
      return FileUtils.writeFile(
        filePath,
        result.source,
        'usecase',
        force: true,
        dryRun: config.dryRun,
        verbose: config.verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
    );
  }
}
