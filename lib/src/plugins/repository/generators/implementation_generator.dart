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
          ..body = Code(
            config.enableCache
                ? '_remoteDataSource.isInitialized'
                : '_dataSource.isInitialized',
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
          ..body = Code(
            config.enableCache
                ? 'return _remoteDataSource.initialize(params);'
                : 'return _dataSource.initialize(params);',
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
            ..body = Code('return _dataSource.get(params);'),
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
            ..body = Code('return _dataSource.getList(params);'),
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
            ..body = Code('return _dataSource.create($entityCamel);'),
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
            ..body = Code('return _dataSource.update(params);'),
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
            ..body = Code('return _dataSource.delete(params);'),
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
            ..body = Code('return _dataSource.watch(params);'),
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
            ..body = Code('return _dataSource.watchList(params);'),
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
    return Block(
      (b) => b
        ..statements.add(
          Code("if (await _cachePolicy.isValid('$baseCacheKey')) {"),
        )
        ..statements.add(Code('  try {'))
        ..statements.add(Code('    return await _localDataSource.get(params);'))
        ..statements.add(Code('  } catch (e) {'))
        ..statements.add(
          Code("    logger.severe('Cache miss, fetching from remote');"),
        )
        ..statements.add(Code('  }'))
        ..statements.add(Code('}'))
        ..statements.add(
          declareFinal('data')
              .assign(
                refer(
                  '_remoteDataSource',
                ).property('get').call([refer('params')]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('save').call([refer('data')]).awaited.statement,
        )
        ..statements.add(
          refer('_cachePolicy')
              .property('markFresh')
              .call([literalString(baseCacheKey)])
              .awaited
              .statement,
        )
        ..statements.add(refer('data').returned.statement),
    );
  }

  Block _buildCacheAwareGetListBody(String baseCacheKey) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('listCacheKey')
              .assign(
                CodeExpression(Code("'${baseCacheKey}_\${params.hashCode}'")),
              )
              .statement,
        )
        ..statements.add(
          Code('if (await _cachePolicy.isValid(listCacheKey)) {'),
        )
        ..statements.add(Code('  try {'))
        ..statements.add(
          Code('    return await _localDataSource.getList(params);'),
        )
        ..statements.add(Code('  } catch (e) {'))
        ..statements.add(
          Code("    logger.severe('Cache miss, fetching from remote');"),
        )
        ..statements.add(Code('  }'))
        ..statements.add(Code('}'))
        ..statements.add(
          declareFinal('data')
              .assign(
                refer(
                  '_remoteDataSource',
                ).property('getList').call([refer('params')]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('saveAll').call([refer('data')]).awaited.statement,
        )
        ..statements.add(
          refer('_cachePolicy')
              .property('markFresh')
              .call([refer('listCacheKey')])
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
    return Block(
      (b) => b
        ..statements.add(
          Code('late final StreamController<$entityName> controller;'),
        )
        ..statements.add(Code('StreamSubscription<$entityName>? localSub;'))
        ..statements.add(Code('StreamSubscription<$entityName>? remoteSub;'))
        ..statements.add(Code('controller = StreamController<$entityName>('))
        ..statements.add(Code('  onListen: () {'))
        ..statements.add(
          Code('    localSub = _localDataSource.watch(params).listen('),
        )
        ..statements.add(Code('      controller.add,'))
        ..statements.add(Code('      onError: controller.addError,'))
        ..statements.add(Code('    );'))
        ..statements.add(
          Code('    remoteSub = _remoteDataSource.watch(params).listen('),
        )
        ..statements.add(Code('      (data) async {'))
        ..statements.add(Code('        try {'))
        ..statements.add(Code('          await _localDataSource.save(data);'))
        ..statements.add(
          Code("          await _cachePolicy.markFresh('$baseCacheKey');"),
        )
        ..statements.add(Code('        } catch (e) {'))
        ..statements.add(
          Code(
            "          logger.warning('Failed to persist remote update: \${e}');",
          ),
        )
        ..statements.add(Code('        }'))
        ..statements.add(Code('      },'))
        ..statements.add(
          Code(
            "      onError: (e) => logger.warning('Remote watch error: \${e}'),",
          ),
        )
        ..statements.add(Code('    );'))
        ..statements.add(Code('  },'))
        ..statements.add(Code('  onCancel: () async {'))
        ..statements.add(Code('    await remoteSub?.cancel();'))
        ..statements.add(Code('    await localSub?.cancel();'))
        ..statements.add(Code('  },'))
        ..statements.add(Code(');'))
        ..statements.add(Code('return controller.stream;')),
    );
  }

  Block _buildWatchListBody(GeneratorConfig config, String entityName) {
    final baseCacheKey = '${config.nameSnake}_cache';
    return Block(
      (b) => b
        ..statements.add(
          Code('late final StreamController<List<$entityName>> controller;'),
        )
        ..statements.add(
          Code('StreamSubscription<List<$entityName>>? localSub;'),
        )
        ..statements.add(
          Code('StreamSubscription<List<$entityName>>? remoteSub;'),
        )
        ..statements.add(
          Code('controller = StreamController<List<$entityName>>('),
        )
        ..statements.add(Code('  onListen: () {'))
        ..statements.add(
          Code('    localSub = _localDataSource.watchList(params).listen('),
        )
        ..statements.add(Code('      controller.add,'))
        ..statements.add(Code('      onError: controller.addError,'))
        ..statements.add(Code('    );'))
        ..statements.add(
          Code('    remoteSub = _remoteDataSource.watchList(params).listen('),
        )
        ..statements.add(Code('      (data) async {'))
        ..statements.add(Code('        try {'))
        ..statements.add(
          Code('          await _localDataSource.saveAll(data);'),
        )
        ..statements.add(
          Code("          await _cachePolicy.markFresh('$baseCacheKey');"),
        )
        ..statements.add(Code('        } catch (e) {'))
        ..statements.add(
          Code(
            "          logger.warning('Failed to persist remote update: \${e}');",
          ),
        )
        ..statements.add(Code('        }'))
        ..statements.add(Code('      },'))
        ..statements.add(
          Code(
            "      onError: (e) => logger.warning('Remote watch error: \${e}'),",
          ),
        )
        ..statements.add(Code('    );'))
        ..statements.add(Code('  },'))
        ..statements.add(Code('  onCancel: () async {'))
        ..statements.add(Code('    await remoteSub?.cancel();'))
        ..statements.add(Code('    await localSub?.cancel();'))
        ..statements.add(Code('  },'))
        ..statements.add(Code(');'))
        ..statements.add(Code('return controller.stream;')),
    );
  }
}
