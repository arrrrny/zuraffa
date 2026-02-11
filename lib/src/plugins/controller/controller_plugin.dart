import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'builders/controller_class_builder.dart';

class ControllerPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ControllerClassBuilder classBuilder;

  ControllerPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ControllerClassBuilder? classBuilder,
  }) : classBuilder = classBuilder ?? const ControllerClassBuilder();

  @override
  String get id => 'controller';

  @override
  String get name => 'Controller Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateController || config.generateVpc)) {
      return [];
    }
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final controllerName = '${entityName}Controller';
    final presenterName = '${entityName}Presenter';
    final stateName = '${entityName}State';
    final fileName = '${entitySnake}_controller.dart';

    final controllerDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(controllerDirPath, fileName);

    final withState = config.generateState;
    final methods = _buildMethods(config, entityName, entityCamel, withState);
    final imports = _buildImports(config, entitySnake, withState);

    final content = classBuilder.build(
      ControllerClassSpec(
        className: controllerName,
        presenterName: presenterName,
        stateClassName: withState ? stateName : null,
        withState: withState,
        methods: methods,
        imports: imports,
      ),
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'controller',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }

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
              ..defaultTo = Code('const ListQueryParams()'),
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
              ..defaultTo = Code('const ListQueryParams()'),
          ),
          _cancelTokenParam(),
        ])
        ..body = body,
    );
  }

  Block _buildGetWithStateBody(
    String entityName,
    String entityCamel,
    String args,
  ) {
    final resultCall = refer(
      '_presenter',
    ).property('get$entityName').call(_callArgsExpressions(args)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isGetting': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['entity'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGetting': literalBool(false),
                    entityCamel: refer('entity'),
                  }),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGetting': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildGetWithoutStateBody(String entityName, String args) {
    final resultCall = refer(
      '_presenter',
    ).property('get$entityName').call(_callArgsExpressions(args)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['entity'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildGetListWithStateBody(String entityName, String entityCamel) {
    final resultCall = refer('_presenter')
        .property('get${entityName}List')
        .call(_callArgsExpressions('params'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isGettingList': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['list'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGettingList': literalBool(false),
                    '${entityCamel}List': refer('list'),
                  }),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGettingList': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildGetListWithoutStateBody(String entityName) {
    final resultCall = refer('_presenter')
        .property('get${entityName}List')
        .call(_callArgsExpressions('params'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['list'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildCreateWithStateBody(
    String entityName,
    String entityCamel,
    bool hasListMethod,
    bool hasWatchList,
  ) {
    final resultCall = refer('_presenter')
        .property('create$entityName')
        .call(_callArgsExpressions(entityCamel))
        .awaited;
    final updateArgs = <String, Expression>{'isCreating': literalBool(false)};
    if (hasListMethod && !hasWatchList) {
      updateArgs['${entityCamel}List'] = CodeExpression(
        Code('[...viewState.${entityCamel}List, created]'),
      );
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isCreating': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['created'],
            successBody: Block(
              (bb) => bb..statements.add(_updateStateStatement(updateArgs)),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isCreating': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildCreateWithoutStateBody(String entityName, String entityCamel) {
    final resultCall = refer('_presenter')
        .property('create$entityName')
        .call(_callArgsExpressions(entityCamel))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['created'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildUpdateWithStateBody(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool hasListMethod,
    bool hasWatchList,
  ) {
    final resultCall = refer('_presenter')
        .property('update$entityName')
        .call(_callArgsExpressions('${config.idField}, data'))
        .awaited;
    final updateArgs = <String, Expression>{
      'isUpdating': literalBool(false),
      entityCamel: CodeExpression(
        Code(
          'viewState.$entityCamel?.${config.queryField} == updated.${config.queryField} ? updated : viewState.$entityCamel',
        ),
      ),
    };
    if (hasListMethod && !hasWatchList) {
      updateArgs['${entityCamel}List'] = CodeExpression(
        Code(
          'viewState.${entityCamel}List.map((e) => e.${config.queryField} == updated.${config.queryField} ? updated : e).toList()',
        ),
      );
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isUpdating': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['updated'],
            successBody: Block(
              (bb) => bb..statements.add(_updateStateStatement(updateArgs)),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isUpdating': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildUpdateWithoutStateBody(
    GeneratorConfig config,
    String entityName,
  ) {
    final resultCall = refer('_presenter')
        .property('update$entityName')
        .call(_callArgsExpressions('${config.idField}, data'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['updated'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildDeleteWithStateBody(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool hasListMethod,
  ) {
    final resultCall = refer('_presenter')
        .property('delete$entityName')
        .call(_callArgsExpressions(config.idField))
        .awaited;
    final deleteArgs = <String, Expression>{'isDeleting': literalBool(true)};
    if (hasListMethod) {
      deleteArgs['${entityCamel}List'] = CodeExpression(
        Code(
          'viewState.${entityCamel}List.where((e) => e.${config.queryField} != ${config.queryField}).toList()',
        ),
      );
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(_updateStateStatement(deleteArgs))
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['_'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({'isDeleting': literalBool(false)}),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isDeleting': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildDeleteWithoutStateBody(String entityName, String idField) {
    final resultCall = refer(
      '_presenter',
    ).property('delete$entityName').call(_callArgsExpressions(idField)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['_'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildWatchWithStateBody(
    String entityName,
    String entityCamel,
    String args,
  ) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['entity'],
      successBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatching': literalBool(false),
              entityCamel: refer('entity'),
            }),
          ),
      ),
      failureParams: ['failure'],
      failureBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatching': literalBool(false),
              'error': refer('failure'),
            }),
          ),
      ),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch$entityName')
        .call(_callArgsExpressions(args))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isWatching': literalBool(true)}),
        )
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchWithoutStateBody(String entityName, String args) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['entity'],
      successBody: Block((bb) => bb),
      failureParams: ['failure'],
      failureBody: Block((bb) => bb),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch$entityName')
        .call(_callArgsExpressions(args))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchListWithStateBody(String entityName, String entityCamel) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['list'],
      successBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatchingList': literalBool(false),
              '${entityCamel}List': refer('list'),
            }),
          ),
      ),
      failureParams: ['failure'],
      failureBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatchingList': literalBool(false),
              'error': refer('failure'),
            }),
          ),
      ),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch${entityName}List')
        .call(_callArgsExpressions('params'))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isWatchingList': literalBool(true)}),
        )
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchListWithoutStateBody(String entityName) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['list'],
      successBody: Block((bb) => bb),
      failureParams: ['failure'],
      failureBody: Block((bb) => bb),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch${entityName}List')
        .call(_callArgsExpressions('params'))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Parameter _cancelTokenParam() {
    return Parameter(
      (p) => p
        ..name = 'cancelToken'
        ..type = refer('CancelToken?')
        ..defaultTo = Code('null'),
    );
  }

  List<Expression> _callArgsExpressions(String args) {
    final parts = args
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final expressions = parts.map(refer).toList();
    expressions.add(refer('token'));
    return expressions;
  }

  Code _tokenStatement() {
    return declareFinal('token')
        .assign(
          refer('cancelToken').ifNullThen(refer('createCancelToken').call([])),
        )
        .statement;
  }

  Code _updateStateStatement(Map<String, Expression> updates) {
    return refer('updateState').call([
      refer('viewState').property('copyWith').call([], updates),
    ]).statement;
  }

  Code _resultFold({
    required String resultVar,
    required List<String> successParams,
    required Block successBody,
    required List<String> failureParams,
    required Block failureBody,
  }) {
    final success = Method(
      (m) => m
        ..requiredParameters.addAll(
          successParams.map((name) => Parameter((p) => p..name = name)),
        )
        ..body = successBody,
    );
    final failure = Method(
      (m) => m
        ..requiredParameters.addAll(
          failureParams.map((name) => Parameter((p) => p..name = name)),
        )
        ..body = failureBody,
    );
    return refer(
      resultVar,
    ).property('fold').call([success.closure, failure.closure]).statement;
  }

  List<String> _buildImports(
    GeneratorConfig config,
    String entitySnake,
    bool withState,
  ) {
    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '${entitySnake}_presenter.dart',
    ];

    if (withState) {
      imports.add('${entitySnake}_state.dart');
    }

    if (config.methods.any(
      (m) =>
          m == 'create' || m == 'update' || m == 'getList' || m == 'watchList',
    )) {
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      imports.add(entityPath);
    }

    return imports;
  }
}
