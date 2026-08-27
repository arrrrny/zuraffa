part of 'implementation_generator.dart';

/// Extension that generates sync-enabled repository methods.
///
/// Mirrors [RepositoryImplementationGeneratorCached] but inverts the
/// data flow: local is the source of truth, not remote.
///
/// - Reads (`get`, `getList`) delegate to local only — no network calls.
/// - Writes (`create`, `update`, `delete`) write to local first and mark
///   the record as pending sync via the injected [SyncStrategy].
/// - Sync operations (`syncPending`, `pullRemote`) delegate to the strategy.
extension RepositoryImplementationGeneratorSynced
    on RepositoryImplementationGenerator {
  /// Generates a single sync-enabled method for the given CRUD verb.
  Method _generateSyncedMethod(
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
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = _buildSyncedGetBody(),
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
            ..body = _buildSyncedGetListBody(),
        );
      // #406: `list` mirrors the interface method set so sync mode stays
      // analyzable (otherwise DataXRepository is abstract — missing
      // concrete implementation of XRepository.list).
      case 'list':
        return Method(
          (m) => m
            ..name = 'list'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<List<$entityName>>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('NoParams'),
              ),
            )
            ..body = _buildSyncedGetListBody(methodName: 'list'),
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
            ..body = _buildSyncedCreateBody(entityCamel),
        );
      case 'update':
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        final updateParamsType =
            'UpdateParams<${config.idFieldType}, $dataType>';
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
                  ..type = refer(updateParamsType),
              ),
            )
            ..body = _buildSyncedUpdateBody(),
        );
      case 'toggle':
        final fieldEnum = 'Field<${config.name}, dynamic>';
        return Method(
          (m) => m
            ..name = 'toggle'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<${config.name}>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(
                    'ToggleParams<${config.idFieldType}, $fieldEnum>',
                  ),
              ),
            )
            ..body = _buildSyncedUpdateBody(),
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
                  ..type = refer('DeleteParams<${config.idFieldType}>'),
              ),
            )
            ..body = _buildSyncedDeleteBody(),
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
            ..body = _buildSyncedWatchBody(entityName),
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
            ..body = _buildSyncedWatchListBody(entityName),
        );
      default:
        return Method((m) => m..name = '_noop');
    }
  }

  /// `get()` — reads from local only, no network call.
  Block _buildSyncedGetBody() {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('get').call([refer('params')]).awaited.returned.statement,
        ),
    );
  }

  /// `getList()` — reads from local only, no network call.
  Block _buildSyncedGetListBody({String methodName = 'getList'}) {
    return Block(
      (b) => b
        ..statements.add(
          refer('_localDataSource')
              .property(methodName)
              .call([refer('params')])
              .awaited
              .returned
              .statement,
        ),
    );
  }

  /// `create(entity)` — writes to local first, marks pending sync.
  Block _buildSyncedCreateBody(String entityCamel) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('saved')
              .assign(
                refer(
                  '_localDataSource',
                ).property('create').call([refer(entityCamel)]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer('_syncStrategy')
              .property('markPending')
              .call(
                [refer('saved').property('id')],
                {},
                [refer('SyncOperation.create')],
              )
              .awaited
              .statement,
        )
        ..statements.add(refer('saved').returned.statement),
    );
  }

  /// `update(params)` — writes to local first, marks pending sync.
  Block _buildSyncedUpdateBody() {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('saved')
              .assign(
                refer(
                  '_localDataSource',
                ).property('update').call([refer('params')]).awaited,
              )
              .statement,
        )
        ..statements.add(
          refer('_syncStrategy')
              .property('markPending')
              .call(
                [refer('saved').property('id')],
                {},
                [refer('SyncOperation.update')],
              )
              .awaited
              .statement,
        )
        ..statements.add(refer('saved').returned.statement),
    );
  }

  /// `delete(params)` — hard-deletes from local, marks tombstone for remote.
  Block _buildSyncedDeleteBody() {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('delete').call([refer('params')]).awaited.statement,
        )
        ..statements.add(
          refer('_syncStrategy')
              .property('markDeleted')
              .call([
                refer('params').property('id').property('toString').call([]),
              ])
              .awaited
              .statement,
        ),
    );
  }

  /// `watch(params)` — streams from local only.
  Block _buildSyncedWatchBody(String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('watch').call([refer('params')]).returned.statement,
        ),
    );
  }

  /// `watchList(params)` — streams from local only.
  Block _buildSyncedWatchListBody(String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            '_localDataSource',
          ).property('watchList').call([refer('params')]).returned.statement,
        ),
    );
  }

  /// Generates the `syncPending` method that delegates to the sync strategy.
  Method generateSyncPendingMethod() {
    return Method(
      (m) => m
        ..name = 'syncPending'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?')
              ..named = true,
          ),
        )
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('_syncStrategy')
                  .property('syncPending')
                  .call([], {'cancelToken': refer('cancelToken')})
                  .awaited
                  .statement,
            ),
        ),
    );
  }

  /// Generates the `pullRemote` method that delegates to the sync strategy.
  Method generatePullRemoteMethod() {
    return Method(
      (m) => m
        ..name = 'pullRemote'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?')
              ..named = true,
          ),
        )
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('_syncStrategy')
                  .property('pullRemote')
                  .call([], {'cancelToken': refer('cancelToken')})
                  .awaited
                  .statement,
            ),
        ),
    );
  }
}
