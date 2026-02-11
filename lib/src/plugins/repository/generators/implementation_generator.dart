import 'dart:io';
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class RepositoryImplementationGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppendExecutor appendExecutor;

  RepositoryImplementationGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    AppendExecutor? appendExecutor,
  }) : appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';

    final fileName = 'data_${entitySnake}_repository.dart';
    final filePath = '$outputDir/data/repositories/$fileName';

    final methods = <Method>[];

    final dataSourceName = '${entityName}DataSource';
    final localDataSourceName = '${entityName}LocalDataSource';

    final fields = <Field>[];
    final constructors = <Constructor>[];
    if (config.generateLocal) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_dataSource',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_dataSource'
                  ..toThis = true,
              ),
            ),
        ),
      );
    } else if (config.enableCache) {
      fields.addAll([
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_remoteDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_localDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('CachePolicy')
            ..name = '_cachePolicy',
        ),
      ]);
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.addAll([
              Parameter(
                (p) => p
                  ..name = '_remoteDataSource'
                  ..toThis = true,
              ),
              Parameter(
                (p) => p
                  ..name = '_localDataSource'
                  ..toThis = true,
              ),
              Parameter(
                (p) => p
                  ..name = '_cachePolicy'
                  ..toThis = true,
              ),
            ]),
        ),
      );
    } else {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_dataSource',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_dataSource'
                  ..toThis = true,
              ),
            ),
        ),
      );
    }

    if (config.generateInit) {
      final isInitializedGetter = Method(
        (m) => m
          ..name = 'isInitialized'
          ..type = MethodType.getter
          ..annotations.add(refer('override'))
          ..returns = refer('Stream<bool>')
          ..body = Block(
            (b) => b
              ..statements.add(
                refer(config.enableCache ? '_remoteDataSource' : '_dataSource')
                    .property('isInitialized')
                    .returned
                    .statement,
              ),
          ),
      );
      final initializeMethod = Method(
        (m) => m
          ..name = 'initialize'
          ..annotations.add(refer('override'))
          ..returns = refer('Future<void>')
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer('InitializationParams'),
            ),
          )
          ..body = Block(
            (b) => b
              ..statements.add(
                refer(config.enableCache ? '_remoteDataSource' : '_dataSource')
                    .property('initialize')
                    .call([refer('params')])
                    .returned
                    .statement,
              ),
          ),
      );
      methods.add(isInitializedGetter);
      methods.add(initializeMethod);
    }

    for (final method in config.methods) {
      if (config.enableCache) {
        methods.add(
          _generateCachedMethod(config, method, entityName, entityCamel),
        );
      } else {
        methods.add(
          _generateSimpleMethod(config, method, entityName, entityCamel),
        );
      }
    }

    final dataSourceImports = config.generateLocal
        ? ['../data_sources/$entitySnake/${entitySnake}_local_data_source.dart']
        : config.enableCache
        ? [
            '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
            '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
          ]
        : ['../data_sources/$entitySnake/${entitySnake}_data_source.dart'];

    final hasWatchMethods = config.methods.any(
      (m) => m == 'watch' || m == 'watchList',
    );
    final includeAsyncImport = config.enableCache && hasWatchMethods;

    final directives = <Directive>[
      if (includeAsyncImport) Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import('../../domain/entities/$entitySnake/$entitySnake.dart'),
      Directive.import(
        '../../domain/repositories/${entitySnake}_repository.dart',
      ),
      ...dataSourceImports.map(Directive.import),
    ];

    final clazz = Class(
      (c) => c
        ..name = dataRepoName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(repoName))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );
    final library = const SpecLibrary().library(
      specs: [clazz],
      directives: directives,
    );
    final content = const SpecLibrary().emitLibrary(library);

    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      final importPaths = _buildImportPaths(config, entitySnake);
      final importLines = _buildImportLines(importPaths);
      final mergedImports = _mergeImports(existing, importLines);
      final appended = _appendMethods(
        source: mergedImports,
        className: dataRepoName,
        methods: methods,
      );
      return FileUtils.writeFile(
        filePath,
        appended,
        'data_repository',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'data_repository',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Method _generateSimpleMethod(
    GeneratorConfig config,
    String method,
    String entityName,
    String entityCamel,
  ) {
    switch (method) {
      case 'get':
        return Method(
          (m) => m
            ..name = 'get'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('get')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'getList':
        return Method(
          (m) => m
            ..name = 'getList'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('getList')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'create':
        return Method(
          (m) => m
            ..name = 'create'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = entityCamel
                  ..type = refer(entityName),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('create')
                      .call([refer(entityCamel)])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'update':
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        return Method(
          (m) => m
            ..name = 'update'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<${config.name}>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('UpdateParams<${config.idType}, $dataType>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('update')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'delete':
        return Method(
          (m) => m
            ..name = 'delete'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('DeleteParams<${config.idType}>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('delete')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'watch':
        return Method(
          (m) => m
            ..name = 'watch'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('watch')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'watchList':
        return Method(
          (m) => m
            ..name = 'watchList'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('watchList')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      default:
        return Method((m) => m..name = '_noop');
    }
  }

  Method _generateCachedMethod(
    GeneratorConfig config,
    String method,
    String entityName,
    String entityCamel,
  ) {
    final baseCacheKey = '${config.nameSnake}_cache';

    switch (method) {
      case 'get':
        return Method(
          (m) => m
            ..name = 'get'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = _buildCacheAwareGetBody(baseCacheKey),
        );
      case 'getList':
        return Method(
          (m) => m
            ..name = 'getList'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<List<$entityName>>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = _buildCacheAwareGetListBody(baseCacheKey),
        );
      case 'create':
        return Method(
          (m) => m
            ..name = 'create'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = entityCamel
                  ..type = refer(entityName),
              ),
            )
            ..body = _buildCacheAwareCreateBody(baseCacheKey, entityCamel),
        );
      case 'update':
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        return Method(
          (m) => m
            ..name = 'update'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<${config.name}>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('UpdateParams<${config.idType}, $dataType>'),
              ),
            )
            ..body = _buildCacheAwareUpdateBody(baseCacheKey),
        );
      case 'delete':
        return Method(
          (m) => m
            ..name = 'delete'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('DeleteParams<${config.idType}>'),
              ),
            )
            ..body = _buildCacheAwareDeleteBody(baseCacheKey),
        );
      case 'watch':
        return Method(
          (m) => m
            ..name = 'watch'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = _buildWatchBody(config, entityName),
        );
      case 'watchList':
        return Method(
          (m) => m
            ..name = 'watchList'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = _buildWatchListBody(config, entityName),
        );
      default:
        return Method((m) => m..name = '_noop');
    }
  }

  List<String> _buildImportPaths(GeneratorConfig config, String entitySnake) {
    final hasWatchMethods = config.methods.any(
      (m) => m == 'watch' || m == 'watchList',
    );
    final asyncImport = config.enableCache && hasWatchMethods
        ? 'dart:async'
        : null;

    final imports = <String>[];
    if (asyncImport != null) {
      imports.add(asyncImport);
    }
    imports.add('package:zuraffa/zuraffa.dart');
    imports.add('../../domain/entities/$entitySnake/$entitySnake.dart');
    imports.add('../../domain/repositories/${entitySnake}_repository.dart');

    if (config.generateLocal) {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
      );
    } else if (config.enableCache) {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
      );
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
      );
    } else {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
      );
    }
    return imports;
  }

  List<String> _buildImportLines(List<String> importPaths) {
    return importPaths.map((path) => "import '$path';").toList();
  }

  String _appendMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    for (final method in methods) {
      final methodSource = method.accept(emitter).toString();
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: updated,
          className: className,
          memberSource: methodSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _mergeImports(String source, List<String> imports) {
    var updated = source;
    for (final importLine in imports) {
      if (!updated.contains(importLine)) {
        updated = '$importLine\n$updated';
      }
    }
    return updated;
  }

  Block _buildCacheAwareGetBody(String baseCacheKey) {
    final localCall = refer('_localDataSource').property('get').call([
      refer('params'),
    ]);
    final remoteCall = refer('_remoteDataSource').property('get').call([
      refer('params'),
    ]);
    final catchClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('logger').property('severe').call([
                literalString('Cache miss, fetching from remote'),
              ]).statement,
            )
            ..statements.add(
              declareFinal('remote')
                  .assign(remoteCall.awaited)
                  .statement,
            )
            ..statements.add(
              refer('_localDataSource')
                  .property('save')
                  .call([refer('remote')]).awaited.statement,
            )
            ..statements.add(
              refer('_cachePolicy')
                  .property('markFresh')
                  .call([literalString(baseCacheKey)])
                  .awaited
                  .statement,
            )
            ..statements.add(refer('remote').returned.statement),
        ),
    ).closure;
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('cacheValid')
              .assign(
                refer('_cachePolicy')
                    .property('isValid')
                    .call([literalString(baseCacheKey)])
                    .awaited,
              )
              .statement,
        )
        ..statements.add(
          declareFinal('data')
              .assign(
                refer('cacheValid').conditional(
                  localCall.property('catchError').call([catchClosure]).awaited,
                  remoteCall.awaited,
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer('_localDataSource').property('save').call([refer('data')]),
              )
              .awaited
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer('_cachePolicy')
                    .property('markFresh')
                    .call([literalString(baseCacheKey)]),
              )
              .awaited
              .statement,
        )
        ..statements.add(refer('data').returned.statement),
    );
  }

  Block _buildCacheAwareGetListBody(String baseCacheKey) {
    final localCall = refer('_localDataSource').property('getList').call([
      refer('params'),
    ]);
    final remoteCall = refer('_remoteDataSource').property('getList').call([
      refer('params'),
    ]);
    final catchClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('logger').property('severe').call([
                literalString('Cache miss, fetching from remote'),
              ]).statement,
            )
            ..statements.add(
              declareFinal('remote')
                  .assign(remoteCall.awaited)
                  .statement,
            )
            ..statements.add(
              refer('_localDataSource')
                  .property('saveAll')
                  .call([refer('remote')]).awaited.statement,
            )
            ..statements.add(
              refer('_cachePolicy')
                  .property('markFresh')
                  .call([refer('listCacheKey')])
                  .awaited
                  .statement,
            )
            ..statements.add(refer('remote').returned.statement),
        ),
    ).closure;
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('listCacheKeyBuffer')
              .assign(
                refer('StringBuffer')
                    .call([literalString('${baseCacheKey}_')]),
              )
              .statement,
        )
        ..statements.add(
          refer('listCacheKeyBuffer')
              .property('write')
              .call([refer('params').property('hashCode')]).statement,
        )
        ..statements.add(
          declareFinal('listCacheKey')
              .assign(
                refer('listCacheKeyBuffer').property('toString').call([]),
              )
              .statement,
        )
        ..statements.add(
          declareFinal('cacheValid')
              .assign(
                refer('_cachePolicy')
                    .property('isValid')
                    .call([refer('listCacheKey')])
                    .awaited,
              )
              .statement,
        )
        ..statements.add(
          declareFinal('data')
              .assign(
                refer('cacheValid').conditional(
                  localCall.property('catchError').call([catchClosure]).awaited,
                  remoteCall.awaited,
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer('_localDataSource')
                    .property('saveAll')
                    .call([refer('data')]),
              )
              .awaited
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer('_cachePolicy')
                    .property('markFresh')
                    .call([refer('listCacheKey')]),
              )
              .awaited
              .statement,
        )
        ..statements.add(refer('data').returned.statement),
    );
  }

  Block _buildCacheAwareCreateBody(String baseCacheKey, String entityCamel) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('created')
              .assign(
                refer(
                  '_remoteDataSource',
                ).property('create').call([refer(entityCamel)]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('save').call([refer('created')]).awaited.statement,
        )
        ..statements.add(
          refer('_cachePolicy')
              .property('invalidate')
              .call([literalString(baseCacheKey)])
              .awaited
              .statement,
        )
        ..statements.add(refer('created').returned.statement),
    );
  }

  Block _buildCacheAwareUpdateBody(String baseCacheKey) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('updated')
              .assign(
                refer(
                  '_remoteDataSource',
                ).property('update').call([refer('params')]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('update').call([refer('params')]).awaited.statement,
        )
        ..statements.add(
          refer('_cachePolicy')
              .property('invalidate')
              .call([literalString(baseCacheKey)])
              .awaited
              .statement,
        )
        ..statements.add(refer('updated').returned.statement),
    );
  }

  Block _buildCacheAwareDeleteBody(String baseCacheKey) {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            '_remoteDataSource',
          ).property('delete').call([refer('params')]).awaited.statement,
        )
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('delete').call([refer('params')]).awaited.statement,
        )
        ..statements.add(
          refer('_cachePolicy')
              .property('invalidate')
              .call([literalString(baseCacheKey)])
              .awaited
              .statement,
        ),
    );
  }

  Block _buildWatchBody(GeneratorConfig config, String entityName) {
    final baseCacheKey = '${config.nameSnake}_cache';
    final saveWarningClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..lambda = true
        ..body = refer('logger').property('warning').call([
          literalString('Failed to persist remote update'),
        ]).code,
    ).closure;
    final dataHandler = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'data'))
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('_localDataSource')
                  .property('save')
                  .call([refer('data')])
                  .property('catchError')
                  .call([saveWarningClosure])
                  .awaited
                  .statement,
            )
            ..statements.add(
              refer('_cachePolicy')
                  .property('markFresh')
                  .call([literalString(baseCacheKey)])
                  .awaited
                  .statement,
            ),
        ),
    ).closure;
    final remoteErrorHandler = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..lambda = true
        ..body = refer('logger')
            .property('warning')
            .call([refer('e').property('toString').call([])]).code,
    ).closure;
    final onListen = Method(
      (m) => m
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('localSub')
                  .assign(
                    refer('_localDataSource')
                        .property('watch')
                        .call([refer('params')])
                        .property('listen')
                        .call(
                      [refer('controller').property('add')],
                      {'onError': refer('controller').property('addError')},
                    ),
                  )
                  .statement,
            )
            ..statements.add(
              refer('remoteSub')
                  .assign(
                    refer('_remoteDataSource')
                        .property('watch')
                        .call([refer('params')])
                        .property('listen')
                        .call(
                      [dataHandler],
                      {'onError': remoteErrorHandler},
                    ),
                  )
                  .statement,
            ),
        ),
    ).closure;
    final onCancel = Method(
      (m) => m
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('remoteSub').property('cancel').call([]).awaited.statement,
            )
            ..statements.add(
              refer('localSub').property('cancel').call([]).awaited.statement,
            ),
        ),
    ).closure;
    return Block(
      (b) => b
        ..statements.add(
          declareVar(
            'controller',
            type: refer('StreamController<$entityName>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          declareVar(
            'localSub',
            type: refer('StreamSubscription<$entityName>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          declareVar(
            'remoteSub',
            type: refer('StreamSubscription<$entityName>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          refer('controller')
              .assign(
                refer('StreamController<$entityName>').call(
                  [],
                  {'onListen': onListen, 'onCancel': onCancel},
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('controller').property('stream').returned.statement,
        ),
    );
  }

  Block _buildWatchListBody(GeneratorConfig config, String entityName) {
    final baseCacheKey = '${config.nameSnake}_cache';
    final saveWarningClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..lambda = true
        ..body = refer('logger').property('warning').call([
          literalString('Failed to persist remote update'),
        ]).code,
    ).closure;
    final dataHandler = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'data'))
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('_localDataSource')
                  .property('saveAll')
                  .call([refer('data')])
                  .property('catchError')
                  .call([saveWarningClosure])
                  .awaited
                  .statement,
            )
            ..statements.add(
              refer('_cachePolicy')
                  .property('markFresh')
                  .call([literalString(baseCacheKey)])
                  .awaited
                  .statement,
            ),
        ),
    ).closure;
    final remoteErrorHandler = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..lambda = true
        ..body = refer('logger')
            .property('warning')
            .call([refer('e').property('toString').call([])]).code,
    ).closure;
    final onListen = Method(
      (m) => m
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('localSub')
                  .assign(
                    refer('_localDataSource')
                        .property('watchList')
                        .call([refer('params')])
                        .property('listen')
                        .call(
                      [refer('controller').property('add')],
                      {'onError': refer('controller').property('addError')},
                    ),
                  )
                  .statement,
            )
            ..statements.add(
              refer('remoteSub')
                  .assign(
                    refer('_remoteDataSource')
                        .property('watchList')
                        .call([refer('params')])
                        .property('listen')
                        .call(
                      [dataHandler],
                      {'onError': remoteErrorHandler},
                    ),
                  )
                  .statement,
            ),
        ),
    ).closure;
    final onCancel = Method(
      (m) => m
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('remoteSub').property('cancel').call([]).awaited.statement,
            )
            ..statements.add(
              refer('localSub').property('cancel').call([]).awaited.statement,
            ),
        ),
    ).closure;
    return Block(
      (b) => b
        ..statements.add(
          declareVar(
            'controller',
            type: refer('StreamController<List<$entityName>>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          declareVar(
            'localSub',
            type: refer('StreamSubscription<List<$entityName>>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          declareVar(
            'remoteSub',
            type: refer('StreamSubscription<List<$entityName>>'),
            late: true,
          ).statement,
        )
        ..statements.add(
          refer('controller')
              .assign(
                refer('StreamController<List<$entityName>>').call(
                  [],
                  {'onListen': onListen, 'onCancel': onCancel},
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('controller').property('stream').returned.statement,
        ),
    );
  }
}
