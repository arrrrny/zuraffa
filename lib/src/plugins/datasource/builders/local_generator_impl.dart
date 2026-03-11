part of 'local_generator.dart';

extension LocalDataSourceBuilderImpl on LocalDataSourceBuilder {
  void _generateHiveImplementation(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
    String entityCamel,
    List<Field> fields,
    List<Constructor> constructors,
    List<Method> methods,
  ) {
    final hasListMethods = config.methods.any(
      (m) => m == 'getList' || m == 'watchList',
    );

    fields.add(
      Field(
        (f) => f
          ..modifier = FieldModifier.final$
          ..type = refer('Box<$entityName>')
          ..name = '_box',
      ),
    );
    constructors.add(
      Constructor(
        (c) => c.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = '_box'
              ..toThis = true,
          ),
        ),
      ),
    );

    if (!hasListMethods) {
      methods.add(
        _buildMethodWithBody(
          name: 'save',
          returnType: 'Future<$entityName>',
          parameters: [_param(entityCamel, entityName)],
          body: _awaitThenReturn(
            refer('_box').property('put').call([
              literalString(entitySnake),
              refer(entityCamel),
            ]),
            refer(entityCamel),
          ),
          isAsync: true,
          override: false,
        ),
      );
    } else {
      methods.add(
        _buildMethodWithBody(
          name: 'save',
          returnType: 'Future<$entityName>',
          parameters: [_param(entityCamel, entityName)],
          body: _awaitThenReturn(
            refer('_box').property('put').call([
              refer(entityCamel).property(config.idField),
              refer(entityCamel),
            ]),
            refer(entityCamel),
          ),
          isAsync: true,
          override: false,
        ),
      );
      methods.add(
        _buildMethodWithBody(
          name: 'saveAll',
          returnType: 'Future<void>',
          parameters: [_param('items', 'List<$entityName>')],
          body: _buildSaveAllBody(config.idField),
          isAsync: true,
          override: false,
        ),
      );
    }

    methods.add(
      _buildMethodWithBody(
        name: 'clear',
        returnType: 'Future<void>',
        parameters: const [],
        body: _awaitBody(refer('_box').property('clear').call([])),
        isAsync: true,
        override: false,
      ),
    );

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            _buildMethodWithBody(
              name: 'get',
              returnType: 'Future<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _returnBody(
                refer(
                  '_box',
                ).property('values').property('query').call([refer('params')]),
              ),
              isAsync: true,
            ),
          );
          break;
        case 'getList':
          methods.add(
            _buildMethodWithBody(
              name: 'getList',
              returnType: 'Future<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _returnBody(
                refer('_box')
                    .property('values')
                    .property('filter')
                    .call([refer('params').property('filter')])
                    .property('orderBy')
                    .call([refer('params').property('sort')]),
              ),
              isAsync: true,
            ),
          );
          break;
        case 'create':
          methods.add(
            _buildMethodWithBody(
              name: 'create',
              returnType: 'Future<$entityName>',
              parameters: [_param(entityCamel, entityName)],
              body: hasListMethods
                  ? _awaitThenReturn(
                      refer('_box').property('put').call([
                        refer(entityCamel).property(config.idField),
                        refer(entityCamel),
                      ]),
                      refer(entityCamel),
                    )
                  : _awaitThenReturn(
                      refer('_box').property('put').call([
                        literalString(entitySnake),
                        refer(entityCamel),
                      ]),
                      refer(entityCamel),
                    ),
              isAsync: true,
            ),
          );
          break;
        case 'update':
          final dataType = config.useZorphy
              ? '${config.name}Patch'
              : 'Partial<${config.name}>';
          if (hasListMethods) {
            methods.add(
              _buildMethodWithBody(
                name: 'update',
                returnType: 'Future<${config.name}>',
                parameters: [
                  _param(
                    'params',
                    'UpdateParams<${config.idFieldType}, $dataType>',
                  ),
                ],
                body: config.useZorphy
                    ? _buildUpdateWithZorphyBody(config, entityName)
                    : _buildUpdateWithoutZorphyBody(config, entityName),
                isAsync: true,
              ),
            );
          } else {
            methods.add(
              _buildMethodWithBody(
                name: 'update',
                returnType: 'Future<${config.name}>',
                parameters: [
                  _param(
                    'params',
                    'UpdateParams<${config.idFieldType}, $dataType>',
                  ),
                ],
                body: config.useZorphy
                    ? _buildUpdateSingleWithZorphyBody(
                        config,
                        entityName,
                        entitySnake,
                      )
                    : _buildUpdateSingleWithoutZorphyBody(
                        config,
                        entityName,
                        entitySnake,
                      ),
                isAsync: true,
              ),
            );
          }
          break;
        case 'delete':
          methods.add(
            _buildMethodWithBody(
              name: 'delete',
              returnType: 'Future<void>',
              parameters: [
                _param('params', 'DeleteParams<${config.idFieldType}>'),
              ],
              body: hasListMethods
                  ? _buildDeleteWithListBody(config, entityName)
                  : _awaitBody(
                      refer(
                        '_box',
                      ).property('delete').call([literalString(entitySnake)]),
                    ),
              isAsync: true,
            ),
          );
          break;
        case 'watch':
          methods.add(
            _buildMethodWithBody(
              name: 'watch',
              returnType: 'Stream<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _buildWatchBody(entityName),
              isAsync: false,
            ),
          );
          break;
        case 'watchList':
          methods.add(
            _buildMethodWithBody(
              name: 'watchList',
              returnType: 'Stream<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _buildWatchListBody(entityName),
              isAsync: false,
              override: true,
            ),
          );
          break;
        default:
          break;
      }
    }
  }

  void _generateStubImplementation(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    List<Method> methods,
  ) {
    methods.add(
      _buildMethodWithBody(
        name: 'save',
        returnType: 'Future<$entityName>',
        parameters: [_param(entityCamel, entityName)],
        body: _throwBody('Implement local save'),
        isAsync: true,
        override: false,
      ),
    );
    if (config.idFieldType != 'NoParams') {
      methods.add(
        _buildMethodWithBody(
          name: 'saveAll',
          returnType: 'Future<void>',
          parameters: [_param('items', 'List<$entityName>')],
          body: _throwBody('Implement local saveAll'),
          isAsync: true,
          override: false,
        ),
      );
    }
    methods.add(
      _buildMethodWithBody(
        name: 'clear',
        returnType: 'Future<void>',
        parameters: const [],
        body: _throwBody('Implement local clear'),
        isAsync: true,
        override: false,
      ),
    );

    for (final method in config.methods) {
      final dataType = config.useZorphy
          ? '${config.name}Patch'
          : 'Partial<${config.name}>';
      switch (method) {
        case 'get':
          methods.add(
            _buildMethodWithBody(
              name: 'get',
              returnType: 'Future<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _throwBody('Implement local get'),
              isAsync: true,
            ),
          );
          break;
        case 'getList':
          methods.add(
            _buildMethodWithBody(
              name: 'getList',
              returnType: 'Future<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _throwBody('Implement local getList'),
              isAsync: true,
            ),
          );
          break;
        case 'create':
          methods.add(
            _buildMethodWithBody(
              name: 'create',
              returnType: 'Future<$entityName>',
              parameters: [_param(entityCamel, entityName)],
              body: _throwBody('Implement local create'),
              isAsync: true,
            ),
          );
          break;
        case 'update':
          methods.add(
            _buildMethodWithBody(
              name: 'update',
              returnType: 'Future<${config.name}>',
              parameters: [
                _param(
                  'params',
                  'UpdateParams<${config.idFieldType}, $dataType>',
                ),
              ],
              body: _throwBody('Implement local update'),
              isAsync: true,
            ),
          );
          break;
        case 'delete':
          methods.add(
            _buildMethodWithBody(
              name: 'delete',
              returnType: 'Future<void>',
              parameters: [
                _param('params', 'DeleteParams<${config.idFieldType}>'),
              ],
              body: _throwBody('Implement local delete'),
              isAsync: true,
            ),
          );
          break;
        case 'watch':
          methods.add(
            _buildMethodWithBody(
              name: 'watch',
              returnType: 'Stream<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _throwBody('Implement local watch'),
              isAsync: false,
            ),
          );
          break;
        case 'watchList':
          methods.add(
            _buildMethodWithBody(
              name: 'watchList',
              returnType: 'Stream<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _throwBody('Implement local watchList'),
              isAsync: false,
            ),
          );
          break;
      }
    }
  }
}
