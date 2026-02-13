part of 'implementation_generator.dart';

extension RepositoryImplementationGeneratorCached
    on RepositoryImplementationGenerator {
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

  Block _buildCacheAwareGetBody(String baseCacheKey) {
    final localCall = refer(
      '_localDataSource',
    ).property('get').call([refer('params')]);
    final remoteCall = refer(
      '_remoteDataSource',
    ).property('get').call([refer('params')]);
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
              declareFinal('remote').assign(remoteCall.awaited).statement,
            )
            ..statements.add(
              refer(
                '_localDataSource',
              ).property('save').call([refer('remote')]).awaited.statement,
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
                refer('_cachePolicy').property('isValid').call([
                  literalString(baseCacheKey),
                ]).awaited,
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
                refer(
                  '_localDataSource',
                ).property('save').call([refer('data')]),
              )
              .awaited
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer(
                  '_cachePolicy',
                ).property('markFresh').call([literalString(baseCacheKey)]),
              )
              .awaited
              .statement,
        )
        ..statements.add(refer('data').returned.statement),
    );
  }

  Block _buildCacheAwareGetListBody(String baseCacheKey) {
    final localCall = refer(
      '_localDataSource',
    ).property('getList').call([refer('params')]);
    final remoteCall = refer(
      '_remoteDataSource',
    ).property('getList').call([refer('params')]);
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
              declareFinal('remote').assign(remoteCall.awaited).statement,
            )
            ..statements.add(
              refer(
                '_localDataSource',
              ).property('saveAll').call([refer('remote')]).awaited.statement,
            )
            ..statements.add(
              refer('_cachePolicy')
                  .property('markFresh')
                  .call([
                    literalString('${baseCacheKey}_'),
                    refer('params').property('hashCode'),
                  ])
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
              .assign(refer('StringBuffer').call([literalString(baseCacheKey)]))
              .statement,
        )
        ..statements.add(
          refer('listCacheKeyBuffer').property('write').call([
            literalString('${baseCacheKey}_'),
          ]).statement,
        )
        ..statements.add(
          refer('listCacheKeyBuffer').property('write').call([
            refer('params').property('hashCode'),
          ]).statement,
        )
        ..statements.add(
          declareFinal('listCacheKey')
              .assign(refer('listCacheKeyBuffer').property('toString').call([]))
              .statement,
        )
        ..statements.add(
          declareFinal('cacheValid')
              .assign(
                refer(
                  '_cachePolicy',
                ).property('isValid').call([refer('listCacheKey')]).awaited,
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
                refer(
                  '_localDataSource',
                ).property('saveAll').call([refer('data')]),
              )
              .awaited
              .statement,
        )
        ..statements.add(
          refer('cacheValid')
              .conditional(
                refer('Future').property('value').call([]),
                refer(
                  '_cachePolicy',
                ).property('markFresh').call([refer('listCacheKey')]),
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
          declareFinal('data')
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

  Block _buildCacheAwareUpdateBody(String baseCacheKey) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('data')
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
              .property('markStale')
              .call([literalString(baseCacheKey)])
              .awaited
              .statement,
        ),
    );
  }

  Block _buildWatchBody(GeneratorConfig config, String entityName) {
    final remoteDataSource = _remoteDataSourceRef(config);
    final localDataSource = _localDataSourceRef(config);
    final dataHandler = _buildStreamDataHandler(localDataSource, false);
    final errorHandler = _buildStreamErrorHandler();
    final onListen = _buildOnListen(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      dataHandler: dataHandler,
      errorHandler: errorHandler,
      isList: false,
    );
    final onCancel = _buildOnCancel();
    return _buildStreamControllerBlock(entityName, false, onListen, onCancel);
  }

  Block _buildWatchListBody(GeneratorConfig config, String entityName) {
    final remoteDataSource = _remoteDataSourceRef(config);
    final localDataSource = _localDataSourceRef(config);
    final dataHandler = _buildStreamDataHandler(localDataSource, true);
    final errorHandler = _buildStreamErrorHandler();
    final onListen = _buildOnListen(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      dataHandler: dataHandler,
      errorHandler: errorHandler,
      isList: true,
    );
    final onCancel = _buildOnCancel();
    return _buildStreamControllerBlock(entityName, true, onListen, onCancel);
  }

  Expression _remoteDataSourceRef(GeneratorConfig config) {
    return config.generateLocal
        ? refer('_dataSource')
        : refer('_remoteDataSource');
  }

  Expression _localDataSourceRef(GeneratorConfig config) {
    return config.generateLocal
        ? refer('_dataSource')
        : refer('_localDataSource');
  }

  Expression _buildStreamDataHandler(Expression localDataSource, bool isList) {
    final saveMethod = isList ? 'saveAll' : 'save';
    return Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'data'))
        ..modifier = MethodModifier.async
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer(
                'controller',
              ).property('add').call([refer('data')]).statement,
            )
            ..statements.add(
              localDataSource
                  .property(saveMethod)
                  .call([refer('data')])
                  .awaited
                  .statement,
            ),
        ),
    ).closure;
  }

  Expression _buildStreamErrorHandler() {
    return Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'error'))
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer(
                'controller',
              ).property('addError').call([refer('error')]).statement,
            ),
        ),
    ).closure;
  }

  Expression _buildOnListen({
    required Expression localDataSource,
    required Expression remoteDataSource,
    required Expression dataHandler,
    required Expression errorHandler,
    required bool isList,
  }) {
    final watchMethod = isList ? 'watchList' : 'watch';
    final onDataHandler = refer('controller').property('add');
    final onErrorHandler = refer('controller').property('addError');

    return Method(
      (m) => m
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('localSub')
                  .assign(
                    localDataSource
                        .property(watchMethod)
                        .call([refer('params')])
                        .property('listen')
                        .call([onDataHandler], {'onError': onErrorHandler}),
                  )
                  .statement,
            )
            ..statements.add(
              refer('remoteSub')
                  .assign(
                    remoteDataSource
                        .property(watchMethod)
                        .call([refer('params')])
                        .property('listen')
                        .call([dataHandler], {'onError': errorHandler}),
                  )
                  .statement,
            ),
        ),
    ).closure;
  }

  Expression _buildOnCancel() {
    return Method(
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
  }

  Block _buildStreamControllerBlock(
    String entityName,
    bool isList,
    Expression onListen,
    Expression onCancel,
  ) {
    final streamType = isList ? 'List<$entityName>' : entityName;
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('controller')
              .assign(
                refer(
                  'StreamController',
                ).call(const [], {}, [refer(streamType)]),
              )
              .statement,
        )
        ..statements.add(
          declareVar(
            'localSub',
            type: refer('StreamSubscription<$streamType>'),
          ).statement,
        )
        ..statements.add(
          declareVar(
            'remoteSub',
            type: refer('StreamSubscription<$streamType>'),
          ).statement,
        )
        ..statements.add(
          refer('controller').property('onListen').assign(onListen).statement,
        )
        ..statements.add(
          refer('controller').property('onCancel').assign(onCancel).statement,
        )
        ..statements.add(
          refer('controller').property('stream').returned.statement,
        ),
    );
  }
}
