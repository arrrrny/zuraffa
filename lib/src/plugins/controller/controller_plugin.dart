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
    final callArgs = _callArgs(args);
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isGetting: true));
final result = await _presenter.get$entityName($callArgs);

result.fold(
  (entity) => updateState(viewState.copyWith(
    isGetting: false,
    $entityCamel: entity,
  )),
  (failure) => updateState(viewState.copyWith(
    isGetting: false,
    error: failure,
  )),
);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.get$entityName($callArgs);

result.fold(
  (entity) {},
  (failure) {},
);
''';

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
        ..body = Code(body),
    );
  }

  Method _buildGetListMethod(
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final callArgs = _callArgs('params');
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isGettingList: true));
final result = await _presenter.get${entityName}List($callArgs);

result.fold(
  (list) => updateState(viewState.copyWith(
    isGettingList: false,
    ${entityCamel}List: list,
  )),
  (failure) => updateState(viewState.copyWith(
    isGettingList: false,
    error: failure,
  )),
);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.get${entityName}List($callArgs);

result.fold(
  (list) {},
  (failure) {},
);
''';

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
        ..body = Code(body),
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
    final listUpdate = (hasListMethod && !hasWatchList)
        ? '${entityCamel}List: [...viewState.${entityCamel}List, created],'
        : '';
    final callArgs = _callArgs(entityCamel);
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isCreating: true));
final result = await _presenter.create$entityName($callArgs);

result.fold(
  (created) => updateState(viewState.copyWith(
    isCreating: false,
    $listUpdate
  )),
  (failure) => updateState(viewState.copyWith(
    isCreating: false,
    error: failure,
  )),
);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.create$entityName($callArgs);

result.fold(
  (created) {},
  (failure) {},
);
''';

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
        ..body = Code(body),
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
    final listUpdate = (hasListMethod && !hasWatchList)
        ? '${entityCamel}List: viewState.${entityCamel}List.map((e) => e.${config.queryField} == updated.${config.queryField} ? updated : e).toList(),'
        : '';
    final singleUpdate =
        '$entityCamel: viewState.$entityCamel?.${config.queryField} == updated.${config.queryField} ? updated : viewState.$entityCamel,';
    final callArgs = _callArgs('${config.idField}, data');
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isUpdating: true));
final result = await _presenter.update$entityName($callArgs);

result.fold(
  (updated) => updateState(viewState.copyWith(
    isUpdating: false,
    $listUpdate
    $singleUpdate
  )),
  (failure) => updateState(viewState.copyWith(
    isUpdating: false,
    error: failure,
  )),
);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.update$entityName($callArgs);

result.fold(
  (updated) {},
  (failure) {},
);
''';

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
        ..body = Code(body),
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
    final listUpdate = hasListMethod
        ? '${entityCamel}List: viewState.${entityCamel}List.where((e) => e.${config.queryField} != ${config.queryField}).toList(),'
        : '';
    final callArgs = _callArgs(config.idField);
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(
  isDeleting: true,
  $listUpdate
));

final result = await _presenter.delete$entityName($callArgs);

result.fold(
  (_) => updateState(viewState.copyWith(isDeleting: false)),
  (failure) => updateState(viewState.copyWith(
    isDeleting: false,
    error: failure,
  )),
);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.delete$entityName($callArgs);

result.fold(
  (_) {},
  (failure) {},
);
''';

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
        ..body = Code(body),
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
    final callArgs = _callArgs(args);
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isWatching: true));
final subscription = _presenter.watch$entityName($callArgs).listen(
  (result) {
    result.fold(
      (entity) => updateState(viewState.copyWith(
        isWatching: false,
        $entityCamel: entity,
      )),
      (failure) => updateState(viewState.copyWith(
        isWatching: false,
        error: failure,
      )),
    );
  },
);
registerSubscription(subscription);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final subscription = _presenter.watch$entityName($callArgs).listen(
  (result) {
    result.fold(
      (entity) {},
      (failure) {},
    );
  },
);
registerSubscription(subscription);
''';

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
        ..body = Code(body),
    );
  }

  Method _buildWatchListMethod(
    String entityName,
    String entityCamel,
    bool withState,
  ) {
    final callArgs = _callArgs('params');
    final body = withState
        ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isWatchingList: true));
final subscription = _presenter.watch${entityName}List($callArgs).listen(
  (result) {
    result.fold(
      (list) => updateState(viewState.copyWith(
        isWatchingList: false,
        ${entityCamel}List: list,
      )),
      (failure) => updateState(viewState.copyWith(
        isWatchingList: false,
        error: failure,
      )),
    );
  },
);
registerSubscription(subscription);
'''
        : '''
final token = cancelToken ?? createCancelToken();
final subscription = _presenter.watch${entityName}List($callArgs).listen(
  (result) {
    result.fold(
      (list) {},
      (failure) {},
    );
  },
);
registerSubscription(subscription);
''';

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
        ..body = Code(body),
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

  String _callArgs(String args) {
    if (args.isEmpty) {
      return 'token';
    }
    return '$args, token';
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
