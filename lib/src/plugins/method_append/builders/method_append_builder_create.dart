part of 'method_append_builder.dart';

extension MethodAppendBuilderCreate on MethodAppendBuilder {
  Future<void> _createRepository(
    GeneratorConfig config,
    String filePath,
    String repoName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = '${repoName}Repository'
        ..abstract = true
        ..docs.add('Repository interface for $repoName')
        ..methods.add(method),
    );

    final content = specLibrary.emitSpec(clazz);
    await FileUtils.writeFile(
      filePath,
      content,
      'repository',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _createService(
    GeneratorConfig config,
    String filePath,
    String serviceName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = serviceName
        ..abstract = true
        ..docs.add('Service interface for ${config.name}')
        ..methods.add(method),
    );

    final library = specLibrary.library(
      specs: [clazz],
      directives: [Directive.import('package:zuraffa/zuraffa.dart')],
    );

    final content = specLibrary.emitLibrary(library);
    await FileUtils.writeFile(
      filePath,
      content,
      'service',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _createProvider(
    GeneratorConfig config,
    String filePath,
    String serviceName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final serviceSnake = config.serviceSnake!;
    final providerName = config.effectiveProvider!;
    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Block(
          (b) => b
            ..statements.add(
              refer(
                'UnimplementedError',
              ).call([literalString('Implement $methodName')]).thrown.statement,
            ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = providerName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..docs.add('/// Provider implementation for $serviceName')
        ..methods.add(method),
    );

    final library = specLibrary.library(
      specs: [clazz],
      directives: [
        Directive.import('package:zuraffa/zuraffa.dart'),
        Directive.import(
          '../../../domain/services/${serviceSnake}_service.dart',
        ),
      ],
    );

    final content = specLibrary.emitLibrary(library);
    await FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
