part of 'controller_plugin.dart';

extension ControllerPluginMethods on ControllerPlugin {
  List<Method> _buildMethods(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final methods = <Method>[];

    // 1. Entity-based methods
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

    // 2. Custom methods
    if (config.isOrchestrator && !config.generateUseCase) {
      for (final u in config.usecases) {
        final info = CommonPatterns.parseUseCaseInfo(u, config, outputDir);
        methods.add(
          _buildCustomMethod(config, info.fieldName, withState, info: info),
        );
      }
    } else if (config.isCustomUseCase && config.methods.isEmpty) {
      methods.add(_buildCustomMethod(config, config.nameCamel, withState));
    }

    return methods;
  }

  Method _buildCustomMethod(
    GeneratorConfig config,
    String methodName,
    bool withState, {
    ParsedUseCaseInfo? info,
  }) {
    final returns = info?.returnsType ?? config.returnsType ?? 'void';
    final params = info?.paramsType ?? config.paramsType ?? 'NoParams';
    final useCaseType = info?.useCaseType ?? config.useCaseType;
    final isStream = useCaseType == 'stream';

    final body = isStream
        ? (withState
              ? _buildCustomStreamWithStateBody(
                  config,
                  methodName,
                  params,
                  returns,
                )
              : _buildCustomStreamWithoutStateBody(
                  config,
                  methodName,
                  params,
                  returns,
                ))
        : (withState
              ? _buildCustomWithStateBody(config, methodName, params, returns)
              : _buildCustomWithoutStateBody(
                  config,
                  methodName,
                  params,
                  returns,
                ));

    return Method(
      (m) => m
        ..name = methodName
        ..returns = isStream ? refer('void') : refer('Future<void>')
        ..modifier = isStream ? null : MethodModifier.async
        ..requiredParameters.addAll(
          params == 'NoParams'
              ? const []
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params),
                  ),
                ],
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = body,
    );
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
              ..name = 'refresh'
              ..type = refer('bool')
              ..defaultTo = literalBool(false).code,
          ),
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>')
              ..defaultTo = refer(
                'ListQueryParams<$entityName>',
              ).constInstance([]).code,
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
    // Use Patch for entity-based updates by default
    final updateDataType = '${entityName}Patch';
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
              ..type = refer(config.idFieldType),
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
              ..type = refer(config.idFieldType),
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
              ..defaultTo = refer(
                'ListQueryParams<$entityName>',
              ).constInstance([]).code,
          ),
          _cancelTokenParam(),
        ])
        ..body = body,
    );
  }
}
