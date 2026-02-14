part of 'controller_plugin.dart';

extension ControllerPluginMethods on ControllerPlugin {
  List<Method> _buildMethods(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final methods = <Method>[];
    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            _buildGetMethod(config, entityName, entityCamel, withState),
          );
          break;
        case 'list':
        case 'getList':
          methods.add(_buildGetListMethod(entityName, entityCamel, withState));
          break;
        case 'create':
          methods.add(
            _buildCreateMethod(entityName, entityCamel, withState, config),
          );
          break;
        case 'update':
          methods.add(
            _buildUpdateMethod(config, entityName, entityCamel, withState),
          );
          break;
        case 'delete':
          methods.add(
            _buildDeleteMethod(config, entityName, entityCamel, withState),
          );
          break;
        case 'watch':
          methods.add(
            _buildWatchMethod(config, entityName, entityCamel, withState),
          );
          break;
        case 'watchList':
          methods.add(
            _buildWatchListMethod(entityName, entityCamel, withState),
          );
          break;
      }
    }
    return methods;
  }

  Method _buildGetMethod(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final hasParams = config.queryFieldType != 'NoParams';
    final args = hasParams ? config.queryField : '';
    final body = withState
        ? _buildGetWithStateBody(entityName, entityCamel, args)
        : _buildGetWithoutStateBody(entityName, args);

    return Method(
      (m) => m
        ..name = 'get$entityName'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..requiredParameters.addAll(
          hasParams
              ? [
                  Parameter(
                    (p) => p
                      ..name = config.queryField
                      ..type = refer(config.queryFieldType),
                  ),
                ]
              : const [],
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
  }

  Method _buildGetListMethod(
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final body = withState
        ? _buildGetListWithStateBody(entityName, entityCamel)
        : _buildGetListWithoutStateBody(entityName);

    return Method(
      (m) => m
        ..name = 'get${entityName}List'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..optionalParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>')
              ..defaultTo = refer('ListQueryParams').constInstance([]).code,
          ),
          _cancelTokenParam(),
        ])
        ..body = body,
    );
  }

  Method _buildCreateMethod(
    String entityName,
    String entityCamel,
    bool withState,
    GeneratorConfig config,
  ) {
    final hasListMethod = config.methods.contains('getList');
    final hasWatchList = config.methods.contains('watchList');
    final body = withState
        ? _buildCreateWithStateBody(
            entityName,
            entityCamel,
            hasListMethod,
            hasWatchList,
          )
        : _buildCreateWithoutStateBody(entityName, entityCamel);

    return Method(
      (m) => m
        ..name = 'create$entityName'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = entityCamel
              ..type = refer(entityName),
          ),
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
  }

  Method _buildUpdateMethod(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final updateDataType = config.useZorphy
        ? '${entityName}Patch'
        : 'Partial<$entityName>';
    final hasListMethod = config.methods.contains('getList');
    final hasWatchList = config.methods.contains('watchList');
    final body = withState
        ? _buildUpdateWithStateBody(
            config,
            entityName,
            entityCamel,
            hasListMethod,
            hasWatchList,
          )
        : _buildUpdateWithoutStateBody(config, entityName);

    return Method(
      (m) => m
        ..name = 'update$entityName'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = config.idField
              ..type = refer(config.idType),
          ),
          Parameter(
            (p) => p
              ..name = 'data'
              ..type = refer(updateDataType),
          ),
        ])
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
  }

  Method _buildDeleteMethod(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final hasListMethod =
        config.methods.contains('getList') ||
        config.methods.contains('watchList');
    final body = withState
        ? _buildDeleteWithStateBody(
            config,
            entityName,
            entityCamel,
            hasListMethod,
          )
        : _buildDeleteWithoutStateBody(entityName, config.idField);

    return Method(
      (m) => m
        ..name = 'delete$entityName'
        ..returns = refer('Future<void>')
        ..modifier = MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = config.idField
              ..type = refer(config.idType),
          ),
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
  }

  Method _buildWatchMethod(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final hasParams = config.queryFieldType != 'NoParams';
    final args = hasParams ? config.queryField : '';
    final body = withState
        ? _buildWatchWithStateBody(entityName, entityCamel, args)
        : _buildWatchWithoutStateBody(entityName, args);

    return Method(
      (m) => m
        ..name = 'watch$entityName'
        ..returns = refer('void')
        ..requiredParameters.addAll(
          hasParams
              ? [
                  Parameter(
                    (p) => p
                      ..name = config.queryField
                      ..type = refer(config.queryFieldType),
                  ),
                ]
              : const [],
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
  }

  Method _buildWatchListMethod(
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final body = withState
        ? _buildWatchListWithStateBody(entityName, entityCamel)
        : _buildWatchListWithoutStateBody(entityName);

    return Method(
      (m) => m
        ..name = 'watch${entityName}List'
        ..returns = refer('void')
        ..optionalParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>')
              ..defaultTo = refer('ListQueryParams').constInstance([]).code,
          ),
          _cancelTokenParam(),
        ])
        ..body = body,
    );
  }
}
