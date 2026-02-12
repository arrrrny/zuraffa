import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/usecase_class_builder.dart';

class StreamUseCaseGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;

  StreamUseCaseGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    UseCaseClassBuilder? classBuilder,
    AppendExecutor? appendExecutor,
  }) : classBuilder = classBuilder ?? const UseCaseClassBuilder(),
       appendExecutor = appendExecutor ?? AppendExecutor();

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

    if (config.hasRepo) {
      final repoName = config.effectiveRepos.first;
      final repoSnake = StringUtils.camelToSnake(
        repoName.replaceAll('Repository', ''),
      );
      dependencyImports.add('../../repositories/${repoSnake}_repository.dart');
      dependencyFields.add(
        Field(
          (b) => b
            ..name = '_repository'
            ..type = refer(repoName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = '_repository'
            ..toThis = true,
        ),
      );
    } else if (config.hasService) {
      final serviceName = config.effectiveService;
      final serviceSnake = config.serviceSnake;
      if (serviceName == null || serviceSnake == null) {
        throw ArgumentError(
          'Service name must be specified via --service or config.service',
        );
      }
      dependencyImports.add('../../services/${serviceSnake}_service.dart');
      dependencyFields.add(
        Field(
          (b) => b
            ..name = '_service'
            ..type = refer(serviceName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = '_service'
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
        ..._entityImports([paramsType, returnsType]),
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

  List<String> _entityImports(List<String> types) {
    final entityNames = <String>{};
    for (final type in types) {
      final regex = RegExp(r'[A-Z][a-zA-Z0-9_]*');
      final matches = regex.allMatches(type);
      for (final match in matches) {
        final name = match.group(0);
        if (name != null &&
            name != 'List' &&
            name != 'Map' &&
            name != 'Set' &&
            name != 'NoParams' &&
            !RegExp(
              r'^(int|double|bool|String|void|dynamic)$',
            ).hasMatch(name)) {
          entityNames.add(name);
        }
      }
    }
    return entityNames
        .map(
          (e) =>
              '../../entities/${StringUtils.camelToSnake(e)}/${StringUtils.camelToSnake(e)}.dart',
        )
        .toList();
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required String methodSource,
    required String content,
  }) async {
    if (config.appendToExisting && File(filePath).existsSync()) {
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
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
