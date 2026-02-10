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

class CustomUseCaseGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;

  CustomUseCaseGenerator({
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

    final baseClass = _baseClass(config, paramsType, returnsType);
    final imports = _buildImports(config, paramsType, returnsType);
    final fields = _buildDependencyFields(config);
    final constructorParams = _buildDependencyParams(fields);
    final methods = _buildMethods(config, paramsType, returnsType, fields);

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: fields,
      constructors: constructorParams.isEmpty
          ? const []
          : [
              Constructor(
                (b) => b..requiredParameters.addAll(constructorParams),
              ),
            ],
      methods: methods,
      imports: imports,
    );

    final content = classBuilder.build(spec);
    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      methodSources: _methodSourcesForAppend(
        config,
        paramsType,
        returnsType,
        fields,
      ),
      content: content,
    );
  }

  Future<GeneratedFile> generateOrchestrator(GeneratorConfig config) async {
    final className = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final fileName = '${classSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.paramsType!;
    final returnsType = config.returnsType!;
    final baseClass = _baseClass(config, paramsType, returnsType);

    final usecaseImports = <String>['package:zuraffa/zuraffa.dart'];
    final usecaseFields = <Field>[];
    final usecaseParams = <Parameter>[];

    for (final usecaseName in config.usecases) {
      final usecasePath = _resolveUseCasePath(config, usecaseName);
      final usecaseClassName = usecaseName.endsWith('UseCase')
          ? usecaseName
          : '${usecaseName}UseCase';
      final baseName = usecaseName.replaceAll('UseCase', '');
      final fieldName = '_${StringUtils.pascalToCamel(baseName)}';

      usecaseImports.add(usecasePath);
      usecaseFields.add(
        Field(
          (b) => b
            ..name = fieldName
            ..type = refer(usecaseClassName)
            ..modifier = FieldModifier.final$,
        ),
      );
      usecaseParams.add(
        Parameter(
          (p) => p
            ..name = fieldName
            ..toThis = true,
        ),
      );
    }

    final entityImports = _entityImports([paramsType, returnsType]);
    usecaseImports.addAll(entityImports);

    final executeMethod = _buildOrchestratorExecute(
      config,
      paramsType,
      returnsType,
    );

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: usecaseFields,
      constructors: [
        Constructor((b) => b..requiredParameters.addAll(usecaseParams)),
      ],
      methods: [executeMethod],
      imports: usecaseImports,
    );

    final content = classBuilder.build(spec);
    return FileUtils.writeFile(
      filePath,
      content,
      'usecase_orchestrator',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<List<GeneratedFile>> generatePolymorphic(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final baseClassName = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final paramsType = config.paramsType!;
    final returnsType = config.returnsType!;

    final baseClass = _baseClass(config, paramsType, returnsType);
    final abstractSpec = UseCaseClassSpec(
      className: baseClassName,
      baseClass: baseClass,
      isAbstract: true,
      imports: ['package:zuraffa/zuraffa.dart'],
    );
    final abstractContent = classBuilder.build(abstractSpec);
    final abstractFileName = '${classSnake}_usecase.dart';
    final abstractFilePath = path.join(usecaseDirPath, abstractFileName);
    files.add(
      await FileUtils.writeFile(
        abstractFilePath,
        abstractContent,
        'usecase_polymorphic_base',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      ),
    );

    for (final variant in config.variants) {
      final variantClassName = '$variant${config.name}UseCase';
      final variantSnake = StringUtils.camelToSnake('$variant${config.name}');
      final variantFileName = '${variantSnake}_usecase.dart';
      final variantFilePath = path.join(usecaseDirPath, variantFileName);

      final repoClassName = config.repo != null
          ? (config.repo!.endsWith('Repository')
                ? config.repo!
                : '${config.repo}Repository')
          : null;

      final fields = <Field>[];
      final constructorParams = <Parameter>[];
      final imports = <String>[
        'package:zuraffa/zuraffa.dart',
        abstractFileName,
      ];

      if (repoClassName != null) {
        final repoSnake = StringUtils.camelToSnake(
          repoClassName.replaceAll('Repository', ''),
        );
        imports.add('../../repositories/${repoSnake}_repository.dart');
        fields.add(
          Field(
            (b) => b
              ..name = '_repository'
              ..type = refer(repoClassName)
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
      }

      final executeMethod = _buildPolymorphicExecute(
        config,
        paramsType,
        returnsType,
        variant,
      );

      final spec = UseCaseClassSpec(
        className: variantClassName,
        baseClass: baseClassName,
        fields: fields,
        constructors: constructorParams.isEmpty
            ? const []
            : [
                Constructor(
                  (b) => b..requiredParameters.addAll(constructorParams),
                ),
              ],
        methods: [executeMethod],
        imports: imports,
      );

      final content = classBuilder.build(spec);
      files.add(
        await FileUtils.writeFile(
          variantFilePath,
          content,
          'usecase_polymorphic_variant',
          force: force,
          dryRun: dryRun,
          verbose: verbose,
        ),
      );
    }

    final factoryClassName = '${config.name}UseCaseFactory';
    final factoryFileName = '${classSnake}_usecase_factory.dart';
    final factoryFilePath = path.join(usecaseDirPath, factoryFileName);
    final factoryClass = _buildPolymorphicFactory(
      config,
      baseClassName,
      factoryClassName,
      paramsType,
    );
    final factoryImports = <String>[
      abstractFileName,
      ...config.variants.map(
        (v) => '${StringUtils.camelToSnake('$v${config.name}')}_usecase.dart',
      ),
    ];
    final factorySpec = UseCaseClassSpec(
      className: factoryClassName,
      fields: factoryClass.fields,
      constructors: factoryClass.constructors,
      methods: factoryClass.methods,
      imports: factoryImports,
    );
    final factoryContent = classBuilder.build(factorySpec);
    files.add(
      await FileUtils.writeFile(
        factoryFilePath,
        factoryContent,
        'usecase_polymorphic_factory',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      ),
    );

    return files;
  }

  String _baseClass(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    switch (config.useCaseType) {
      case 'stream':
        return 'StreamUseCase<$returnsType, $paramsType>';
      case 'background':
        return 'BackgroundUseCase<$returnsType, $paramsType>';
      case 'completable':
        return 'CompletableUseCase<$paramsType>';
      case 'sync':
        return 'SyncUseCase<$returnsType, $paramsType>';
      default:
        return 'UseCase<$returnsType, $paramsType>';
    }
  }

  List<String> _buildImports(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (config.hasRepo) {
      for (final repo in config.effectiveRepos) {
        final repoSnake = StringUtils.camelToSnake(
          repo.replaceAll('Repository', ''),
        );
        imports.add('../../repositories/${repoSnake}_repository.dart');
      }
    }
    if (config.hasService) {
      final serviceSnake = config.serviceSnake!;
      imports.add('../../services/${serviceSnake}_service.dart');
    }
    imports.addAll(_entityImports([paramsType, returnsType]));
    return imports;
  }

  List<Field> _buildDependencyFields(GeneratorConfig config) {
    final fields = <Field>[];
    if (config.hasRepo) {
      for (final repo in config.effectiveRepos) {
        final repoBaseName = repo.replaceAll('Repository', '');
        final repoFieldName =
            '_${StringUtils.pascalToCamel(repoBaseName)}Repository';
        fields.add(
          Field(
            (b) => b
              ..name = repoFieldName
              ..type = refer(repo)
              ..modifier = FieldModifier.final$,
          ),
        );
      }
    }
    if (config.hasService) {
      final serviceName = config.effectiveService!;
      final serviceBaseName = serviceName.endsWith('Service')
          ? serviceName.substring(0, serviceName.length - 7)
          : serviceName;
      final serviceFieldName =
          '_${StringUtils.pascalToCamel(serviceBaseName)}Service';
      fields.add(
        Field(
          (b) => b
            ..name = serviceFieldName
            ..type = refer(serviceName)
            ..modifier = FieldModifier.final$,
        ),
      );
    }
    return fields;
  }

  List<Parameter> _buildDependencyParams(List<Field> fields) {
    return fields
        .map(
          (field) => Parameter(
            (p) => p
              ..name = field.name
              ..toThis = true,
          ),
        )
        .toList();
  }

  List<Method> _buildMethods(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    if (config.useCaseType == 'background') {
      return _buildBackgroundMethods(paramsType, returnsType);
    }
    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
    final depField = dependencyFields.isNotEmpty
        ? dependencyFields.first.name
        : '';

    if (config.useCaseType == 'stream') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        Method(
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
            ..body = Code(body),
        ),
      ];
    }

    if (config.useCaseType == 'sync') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        Method(
          (b) => b
            ..name = 'execute'
            ..returns = refer(returnsType)
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            )
            ..annotations.add(CodeExpression(Code('override')))
            ..body = Code(body),
        ),
      ];
    }

    final body = StringBuffer()
      ..writeln('cancelToken?.throwIfCancelled();')
      ..writeln(
        depField.isEmpty
            ? 'throw UnimplementedError();'
            : 'return await $depField.$methodName(params);',
      );

    final returnTypeRef = config.useCaseType == 'completable'
        ? 'Future<void>'
        : 'Future<$returnsType>';

    return [
      Method(
        (b) => b
          ..name = 'execute'
          ..returns = refer(returnTypeRef)
          ..modifier = MethodModifier.async
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
          ..body = Code(body.toString()),
      ),
    ];
  }

  List<Method> _buildBackgroundMethods(String paramsType, String returnsType) {
    final buildTask = Method(
      (b) => b
        ..name = 'buildTask'
        ..returns = refer('BackgroundTask<$paramsType>')
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Code('return _process;'),
    );

    final processMethod = Method(
      (b) => b
        ..name = '_process'
        ..static = true
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'context'
              ..type = refer('BackgroundTaskContext<$paramsType>'),
          ),
        )
        ..body = Code(
          'try {\n'
          '  final params = context.params;\n'
          '  final result = processData(params);\n'
          '  context.sendData(result);\n'
          '  context.sendDone();\n'
          '} catch (e, stackTrace) {\n'
          '  context.sendError(e, stackTrace);\n'
          '}',
        ),
    );

    final processData = Method(
      (b) => b
        ..name = 'processData'
        ..static = true
        ..returns = refer(returnsType)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Code(
          "throw UnimplementedError('Implement your background processing logic');",
        ),
    );

    return [buildTask, processMethod, processData];
  }

  Method _buildOrchestratorExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    final signature = config.useCaseType == 'stream'
        ? 'Stream<$returnsType>'
        : config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final body = StringBuffer()
      ..writeln('cancelToken?.throwIfCancelled();')
      ..writeln("throw UnimplementedError('Implement orchestration logic');");

    return Method((b) {
      b
        ..name = 'execute'
        ..returns = refer(signature)
        ..modifier = isAsync ? MethodModifier.async : null
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Code(body.toString());
      if (config.useCaseType != 'sync') {
        b.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        );
      }
    });
  }

  Method _buildPolymorphicExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    String variant,
  ) {
    final signature = config.useCaseType == 'stream'
        ? 'Stream<$returnsType>'
        : config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final body = config.useCaseType == 'sync'
        ? "throw UnimplementedError('Implement $variant variant');"
        : "throw UnimplementedError('Implement $variant variant');";

    return Method((b) {
      b
        ..name = 'execute'
        ..returns = refer(signature)
        ..modifier = isAsync ? MethodModifier.async : null
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Code(body);
      if (config.useCaseType != 'sync') {
        b.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        );
      }
    });
  }

  _FactoryClassParts _buildPolymorphicFactory(
    GeneratorConfig config,
    String baseClassName,
    String factoryClassName,
    String paramsType,
  ) {
    final fields = <Field>[];
    final constructorParams = <Parameter>[];
    for (final variant in config.variants) {
      final className = '$variant${config.name}UseCase';
      final fieldName = '_${StringUtils.pascalToCamel(variant)}';
      fields.add(
        Field(
          (b) => b
            ..name = fieldName
            ..type = refer(className)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = fieldName
            ..toThis = true,
        ),
      );
    }

    final switchCases = config.variants
        .map(
          (variant) =>
              "      $variant$paramsType => _${StringUtils.pascalToCamel(variant)},",
        )
        .join('\n');

    final forParamsMethod = Method(
      (b) => b
        ..name = 'forParams'
        ..returns = refer(baseClassName)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Code(
          'return switch (params.runtimeType) {\n'
          '$switchCases\n'
          "      _ => throw UnimplementedError('Unknown params type: \${params.runtimeType}'),\n"
          '    };',
        ),
    );

    final factorySpec = UseCaseClassSpec(
      className: factoryClassName,
      fields: fields,
      constructors: [
        Constructor((b) => b..requiredParameters.addAll(constructorParams)),
      ],
      methods: [forParamsMethod],
    );

    return _FactoryClassParts(
      fields: factorySpec.fields,
      constructors: factorySpec.constructors,
      methods: factorySpec.methods,
    );
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

  String _resolveUseCasePath(GeneratorConfig config, String usecaseName) {
    final name = usecaseName.endsWith('UseCase')
        ? usecaseName.substring(0, usecaseName.length - 7)
        : usecaseName;
    final snakeName = StringUtils.camelToSnake(name);
    return '../$snakeName/${snakeName}_usecase.dart';
  }

  List<String> _methodSourcesForAppend(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    if (config.useCaseType == 'background') {
      final buildTaskSource =
          '@override\nBackgroundTask<$paramsType> buildTask() { return _process; }';
      final processSource =
          'static void _process(BackgroundTaskContext<$paramsType> context) {\n  try {\n    final params = context.params;\n    final result = processData(params);\n    context.sendData(result);\n    context.sendDone();\n  } catch (e, stackTrace) {\n    context.sendError(e, stackTrace);\n  }\n}';
      final processDataSource =
          'static $returnsType processData($paramsType params) {\n  throw UnimplementedError(\'Implement your background processing logic\');\n}';
      return [buildTaskSource, processSource, processDataSource];
    }

    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
    final depField = dependencyFields.isNotEmpty
        ? dependencyFields.first.name
        : '';

    if (config.useCaseType == 'stream') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        '@override\nStream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {\n  $body\n}',
      ];
    }

    if (config.useCaseType == 'sync') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        '@override\n$returnsType execute($paramsType params) {\n  $body\n}',
      ];
    }

    final returnTypeRef = config.useCaseType == 'completable'
        ? 'Future<void>'
        : 'Future<$returnsType>';
    final body = depField.isEmpty
        ? 'throw UnimplementedError();'
        : 'return await $depField.$methodName(params);';
    return [
      '@override\n$returnTypeRef execute($paramsType params, CancelToken? cancelToken) async {\n  cancelToken?.throwIfCancelled();\n  $body\n}',
    ];
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required List<String> methodSources,
    required String content,
  }) async {
    if (config.appendToExisting && File(filePath).existsSync()) {
      var updatedSource = await File(filePath).readAsString();
      var changed = false;
      for (final methodSource in methodSources) {
        final result = appendExecutor.execute(
          AppendRequest.method(
            source: updatedSource,
            className: className,
            memberSource: methodSource,
          ),
        );
        if (result.changed) {
          updatedSource = result.source;
          changed = true;
        }
      }
      if (!changed) {
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
          content: updatedSource,
        );
      }
      return FileUtils.writeFile(
        filePath,
        updatedSource,
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

class _FactoryClassParts {
  final List<Field> fields;
  final List<Constructor> constructors;
  final List<Method> methods;

  const _FactoryClassParts({
    required this.fields,
    required this.constructors,
    required this.methods,
  });
}
