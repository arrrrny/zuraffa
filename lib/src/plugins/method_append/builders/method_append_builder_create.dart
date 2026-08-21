part of 'method_append_builder.dart';

extension MethodAppendBuilderCreate on MethodAppendBuilder {
  Future<void> _createRepository(
    GeneratorConfig config,
    String filePath,
    String repoName,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = params == 'NoParams'
                          ? 'params'
                          : params.toString().toLowerCase()
                      ..type = refer(params as String),
                  ),
                ],
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
    Object params,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = params == 'NoParams'
                          ? 'params'
                          : params.toString().toLowerCase()
                      ..type = refer(params as String),
                  ),
                ],
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

    var content = specLibrary.emitLibrary(library);
    // Emit imports for non-builtin --params / --returns entity types that live
    // under domain/entities/** (skip NoParams, void, primitives). Without this,
    // a freshly-created service interface references undefined types (issue #395 Bug B).
    // Reuse _addMissingImports so the relative path matches the file's actual
    // location (../entities/... for services, ../../../domain/entities/... for providers).
    content = await _addMissingImports(config, content, filePath);
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
    Object params,
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
              ..requiredParameters.addAll(
                params is List<Param>
                    ? params.map(
                        (p) => Parameter(
                          (pp) => pp
                            ..name = p.name
                            ..type = refer(p.type),
                        ),
                      )
                    : [
                        Parameter(
                          (p) => p
                            ..name = 'params'
                            ..type = refer(params as String),
                        ),
                      ],
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

    var content = specLibrary.emitLibrary(library);
    // Emit imports for non-builtin --params / --returns entity types that live
    // under domain/entities/** (skip NoParams, void, primitives). Without this,
    // a freshly-created provider references undefined types (issue #395 Bug B).
    // Reuse _addMissingImports so the relative path matches the provider's
    // actual location (../../../domain/entities/...).
    content = await _addMissingImports(config, content, filePath);
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
