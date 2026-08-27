part of 'test_builder.dart';

extension TestBuilderEntity on TestBuilder {
  /// Generates a test file for a single entity use case method.
  ///
  /// Emits **native** zuraffa mocks (no `package:mocktail`):
  /// a `Throwing{Entity}DataSource` (every datasource method throws) plus a
  /// wired `Data{Entity}Repository` backed by the generated
  /// `{Entity}MockDataSource`. This lets a zuraffa app run end-to-end on full
  /// mock infrastructure without any third-party mocking library.
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @param method Use case method name to generate tests for.
  /// @returns Generated test file metadata.
  Future<GeneratedFile> generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final useService = config.useService;
    final repoName = config.effectiveRepos.isNotEmpty
        ? config.effectiveRepos.first
        : null;
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;

    final targetName = useService && serviceName != null
        ? serviceName
        : repoName;
    if (targetName == null) {
      throw ArgumentError('Either repository or service must be specified');
    }
    final targetSnake = useService && serviceSnake != null
        ? serviceSnake
        : StringUtils.camelToSnake(targetName.replaceAll('Repository', ''));
    final targetDir = useService ? 'services' : 'repositories';
    final targetSuffix = useService ? 'service' : 'repository';

    String className;
    bool isStream = false;
    switch (method) {
      case 'get':
        className = 'Get${entityName}UseCase';
        break;
      case 'getList':
      case 'list':
        className = 'Get${entityName}ListUseCase';
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        break;
      case 'toggle':
        // #289: PR #287 added 'toggle' to the entity-methods default used by
        // the di/test plugins (['get', 'update', 'toggle']) so canonical
        // `zfa make <Entity> --preset=crud --with=vpc,state,di,test` routes to
        // per-method generation. Every other generator (usecase, controller,
        // presenter, view, repository, datasource, di) has a `toggle` case —
        // the per-method test builder must too, otherwise the test plugin
        // crashes with `Unknown method: toggle` before any file is written.
        // Mirrors the usecase generator: `Toggle${entityName}UseCase` returns
        // the toggled entity (Future<Entity>), not a stream and not void.
        className = 'Toggle${entityName}UseCase';
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final fileSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    final fileName = '${fileSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(entitySnake);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    String useCaseFileName;
    if (method == 'getList' || method == 'list') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }

    final packageName = await _resolvePackageName(projectRoot);

    // Use DiscoveryEngine to find the actual files for correct imports
    final entityFile = discovery.findFileSync('$entitySnake.dart');
    final targetFile = discovery.findFileSync(
      '${targetSnake}_$targetSuffix.dart',
    );
    final useCaseFile = discovery.findFileSync(useCaseFileName);

    if (useCaseFile == null) {
      print(
        '  ⚠️  Skipping test generation for $className: UseCase file ($useCaseFileName) not found.',
      );
      return GeneratedFile(path: filePath, type: 'test', action: 'skipped');
    }

    // #354: detect Flutter vs pure-Dart from pubspec.yaml so the test
    // framework + zuraffa core imports resolve. `zfa setup --dart` only
    // wires `test` + `zuraffa` (no `flutter_test`, no `zuraffa_flutter`).
    final isFlutter = await _isFlutterProject(projectRoot);
    // Always import zuraffa core: every generated test defines a
    // `Throwing{Entity}DataSource` (mixin `Loggable`/`FailureHandler`, params
    // types `QueryParams`/`ToggleParams`/`Field`/…) regardless of the use case
    // method under test, so the zuraffa export is required for all methods —
    // including `create`, which previously omitted it and failed to load.
    final directives = <Directive>[
      _testFrameworkImport(isFlutter),
      _zuraffaCoreImport(isFlutter),
    ];

    String toPackageImport(String filePath) {
      final relativeToLib = path.relative(
        filePath,
        from: path.join(projectRoot, 'lib'),
      );
      return 'package:$packageName/$relativeToLib';
    }

    if (entityFile != null) {
      directives.add(Directive.import(toPackageImport(entityFile.path)));
    } else {
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/entities/$entitySnake/$entitySnake.dart',
        ),
      );
    }

    if (targetFile != null) {
      directives.add(Directive.import(toPackageImport(targetFile.path)));
    } else {
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/$targetDir/${targetSnake}_$targetSuffix.dart',
        ),
      );
    }

    directives.add(Directive.import(toPackageImport(useCaseFile.path)));

    // Native mock infrastructure (generated by `zfa make <Entity> --mock`):
    // datasource interface, mock datasource, mock data, and the Data*Repository.
    directives.add(
      Directive.import(
        'package:$packageName/src/data/datasources/$entitySnake/${entitySnake}_datasource.dart',
      ),
    );
    directives.add(
      Directive.import(
        'package:$packageName/src/data/datasources/$entitySnake/${entitySnake}_mock_datasource.dart',
      ),
    );
    directives.add(
      Directive.import(
        'package:$packageName/src/data/mock/${entitySnake}_mock_data.dart',
      ),
    );
    directives.add(
      Directive.import(
        'package:$packageName/src/data/repositories/data_${entitySnake}_repository.dart',
      ),
    );

    // #321: the test file's `main()` body constructs params that reference
    // the id field type directly. When the id field is an enum, the enum
    // barrel import must be emitted here. Resolve it via
    // CommonPatterns.entityImports.
    final sigTypeImports = CommonPatterns.entityImports(
      [config.idFieldType, config.queryFieldType],
      config,
      depth: 3,
      fileSystem: fileSystem,
    );
    for (final importPath in sigTypeImports) {
      final packagePath = importPath.startsWith('../')
          ? importPath.substring('../'.length * 3)
          : importPath;
      directives.add(
        Directive.import('package:$packageName/src/$packagePath'),
      );
    }

    final throwingClass = Class(
      (c) => c
        ..name = 'Throwing${entityName}DataSource'
        ..mixins.add(refer('Loggable'))
        ..mixins.add(refer('FailureHandler'))
        ..implements.add(refer('${entityName}DataSource'))
        ..methods.addAll(_throwingDataSourceMethods(config)),
    );

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          b.statements.add(
            declareVar('useCase', type: refer(className), late: true).statement,
          );
          b.statements.add(
            declareVar(
              'throwingUseCase',
              type: refer(className),
              late: true,
            ).statement,
          );
          b.statements.add(
            declareVar(
              'repository',
              type: refer('Data${entityName}Repository'),
              late: true,
            ).statement,
          );
          b.statements.add(
            declareVar(
              'throwingRepository',
              type: refer('Data${entityName}Repository'),
              late: true,
            ).statement,
          );
          b.statements.add(
            declareVar(
              'mockDataSource',
              type: refer('${entityName}MockDataSource'),
              late: true,
            ).statement,
          );
          b.statements.add(
            declareVar(
              'throwingDataSource',
              type: refer('Throwing${entityName}DataSource'),
              late: true,
            ).statement,
          );

          final setUpBody = Block((s) {
            s.statements.add(
              refer('mockDataSource')
                  .assign(refer('${entityName}MockDataSource').call([]))
                  .statement,
            );
            s.statements.add(
              refer('throwingDataSource')
                  .assign(refer('Throwing${entityName}DataSource').call([]))
                  .statement,
            );
            s.statements.add(
              refer('repository')
                  .assign(
                    refer('Data${entityName}Repository')
                        .call([refer('mockDataSource')]),
                  )
                  .statement,
            );
            s.statements.add(
              refer('throwingRepository')
                  .assign(
                    refer('Data${entityName}Repository')
                        .call([refer('throwingDataSource')]),
                  )
                  .statement,
            );
            s.statements.add(
              refer('useCase')
                  .assign(refer(className).call([refer('repository')]))
                  .statement,
            );
            s.statements.add(
              refer('throwingUseCase')
                  .assign(refer(className).call([refer('throwingRepository')]))
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            g.statements.add(
              declareFinal('t$entityName')
                  .assign(
                    refer('${entityName}MockData')
                        .property('sample$entityName'),
                  )
                  .statement,
            );
            g.statements.addAll(
              _nativeTestCode(config, method, entityName, isStream),
            );
          });

          b.statements.add(
            refer('group').call([
              literalString(className),
              groupBody.toClosure(),
            ]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [throwingClass, mainMethod],
        directives: directives,
      ),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  /// Builds the `Throwing{Entity}DataSource` method overrides. Every datasource
  /// method throws, giving the failure-path test a repository that always fails.
  /// All eight canonical signatures are overridden so the class satisfies
  /// `implements {Entity}DataSource` for any entity regardless of which subset
  /// of methods its use case actually exercises.
  List<Method> _throwingDataSourceMethods(GeneratorConfig config) {
    final e = config.name;
    final id = config.idFieldType;
    final patch = '${e}Patch';
    final self = 'Throwing${e}DataSource';

    Method make(
      String name,
      String ret,
      List<(String, String)> params,
    ) =>
        Method(
          (b) => b
            ..name = name
            ..returns = refer(ret)
            ..annotations.add(refer('override'))
            ..requiredParameters.addAll(
              params.map(
                (p) => Parameter(
                  (pm) => pm..name = p.$1..type = refer(p.$2),
                ),
              ),
            )
            ..body = refer('throw')
                .call([
                  refer('Exception').call([literalString('$self.$name')]),
                ])
                .statement,
        );

    return [
      make('get', 'Future<$e>', [('params', 'QueryParams<$e>')]),
      make('getList', 'Future<List<$e>>', [('params', 'ListQueryParams<$e>')]),
      make('create', 'Future<$e>', [('entity', e)]),
      make('update', 'Future<$e>', [
        ('params', 'UpdateParams<$id, $patch>'),
      ]),
      make('toggle', 'Future<$e>', [
        ('params', 'ToggleParams<$id, Field<$e, dynamic>>'),
      ]),
      make('delete', 'Future<Map<String, dynamic>>', [
        ('params', 'DeleteParams<$id>'),
      ]),
      make('watch', 'Stream<$e>', [('params', 'QueryParams<$e>')]),
      make('watchList', 'Stream<List<$e>>', [
        ('params', 'ListQueryParams<$e>'),
      ]),
    ];
  }

  /// Builds the two test cases (success + failure) for a single use case method
  /// using only native mocks — no `when`/`verify`/`registerFallbackValue`.
  List<Code> _nativeTestCode(
    GeneratorConfig config,
    String method,
    String entityName,
    bool isStream,
  ) {
    final e = entityName;
    final id = config.idFieldType;
    final qf = config.queryField;

    // The legacy mocktail toggle tests hardcoded `value: true`, which only
    // "passed" because the repository was mocked to return Success
    // unconditionally. With native mocks the datasource actually runs
    // `copyWithField(field, value)`; the value's runtime type must match the
    // toggled (id/query) field's declared type or `copyWithField` throws
    // ArgumentError and the use case returns Failure. Emit a type-correct
    // sample value for the id field type so the success path stays green.
    Expression toggleSampleValue(String type) {
      final t = type.replaceAll('?', '').trim();
      switch (t) {
        case 'int':
        case 'num':
          return literalNum(1);
        case 'double':
          return literalNum(1.0);
        case 'bool':
          return literalBool(true);
        case 'String':
        default:
          return literalString('toggled');
      }
    }

    Expression paramsExpr;
    switch (method) {
      case 'get':
      case 'watch':
        paramsExpr = refer('QueryParams<$e>').call([], {
          'filter': refer('Eq').call([
            refer('${e}Fields').property(qf),
            refer('t$e').property(qf),
          ]),
        });
        break;
      case 'getList':
      case 'watchList':
        paramsExpr = refer('ListQueryParams<$e>').call([]);
        break;
      case 'create':
        paramsExpr = refer('t$e');
        break;
      case 'update':
        paramsExpr = refer('UpdateParams<$id, ${e}Patch>').call([], {
          'id': refer('t$e').property(qf),
          'data': refer('${e}Patch').call([]),
        });
        break;
      case 'toggle':
        paramsExpr = refer('ToggleParams<$id, Field<$e, dynamic>>').call([], {
          'id': refer('t$e').property(qf),
          'field': refer('${e}Fields').property(qf),
          'value': toggleSampleValue(config.idFieldType),
        });
        break;
      case 'delete':
        paramsExpr = refer('DeleteParams<$id>').call([], {
          'id': refer('t$e').property(qf),
        });
        break;
      default:
        paramsExpr = refer('t$e');
    }

    final getOrElseThunk = Method(
      (mm) => mm
        ..lambda = true
        ..body =
            refer('throw').call([refer('Exception').call([literalString('not success')])]).code,
    ).closure;

    final successBody = Block((t) {
      if (isStream) {
        t.statements.add(
          declareFinal('result')
              .assign(refer('useCase').property('call').call([paramsExpr]))
              .statement,
        );
        t.statements.add(
          refer('expectLater')
              .call([
                refer('result'),
                refer('emits').call([
                  refer('isA').call([], {}, [refer('Success<$e>')]),
                ]),
              ])
              .statement,
        );
      } else {
        t.statements.add(
          declareFinal('result')
              .assign(
                refer('useCase').property('call').call([paramsExpr]).awaited,
              )
              .statement,
        );
        t.statements.add(
          refer('expect')
              .call([refer('result').property('isSuccess'), literalBool(true)])
              .statement,
        );
        if (method == 'get') {
          t.statements.add(
            refer('expect')
                .call([
                  refer('result').property('getOrElse').call([getOrElseThunk]),
                  refer('equals').call([refer('t$e')]),
                ])
                .statement,
          );
        } else if (method == 'getList') {
          t.statements.add(
            refer('expect')
                .call([
                  refer('result').property('getOrElse').call([getOrElseThunk]),
                  refer('isA').call([], {}, [refer('List<$e>')]),
                ])
                .statement,
          );
        }
      }
    });

    final failureBody = Block((t) {
      if (isStream) {
        t.statements.add(
          refer('expect')
              .call([
                Method(
                  (mm) => mm
                    ..lambda = true
                    ..body = refer('throwingUseCase')
                        .property('call')
                        .call([paramsExpr])
                        .code,
                ).closure,
                refer('throwsA').call([refer('isA').call([refer('Object')])]),
              ])
              .statement,
        );
      } else {
        t.statements.add(
          declareFinal('result')
              .assign(
                refer('throwingUseCase')
                    .property('call')
                    .call([paramsExpr])
                    .awaited,
              )
              .statement,
        );
        t.statements.add(
          refer('expect')
              .call([refer('result').property('isFailure'), literalBool(true)])
              .statement,
        );
      }
    });

    return [
      refer('test').call([
        literalString('should call repository.$method and return result'),
        successBody.toClosure(asAsync: true),
      ]).statement,
      refer('test').call([
        literalString('should return Failure when repository throws'),
        failureBody.toClosure(asAsync: true),
      ]).statement,
    ];
  }
}
