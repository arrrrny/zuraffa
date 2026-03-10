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
        ..docs.add('/// Repository interface for $repoName')
        ..methods.add(method),
    );

    final content = specLibrary.emitSpec(clazz);
    await FileUtils.writeFile(
      filePath,
      content,
      'repository',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
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
        ..docs.add('/// Service interface for $serviceName')
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
      dryRun: options.dryRun,
      verbose: options.verbose,
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

    final providerClass = Class(
      (c) => c
        ..name = '${serviceName}Provider'
        ..extend = refer('BaseProvider')
        ..docs.add('/// Provider implementation for $serviceName')
        ..methods.add(
          Method(
            (m) => m
              ..name = methodName
              ..annotations.add(refer('override'))
              ..returns = returnType
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'params'
                    ..type = refer(paramsType),
                ),
              )
              ..modifier = MethodModifier.async
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer(
                      'throw',
                    ).call([refer('UnimplementedError').call([])]).statement,
                  ),
              ),
          ),
        ),
    );

    final library = specLibrary.library(
      specs: [providerClass],
      directives: [Directive.import('package:zuraffa/zuraffa.dart')],
    );

    final content = specLibrary.emitLibrary(library);
    await FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }
}
