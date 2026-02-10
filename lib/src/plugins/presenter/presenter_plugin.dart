import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/presenter_class_builder.dart';

class PresenterPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final PresenterClassBuilder classBuilder;

  PresenterPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    PresenterClassBuilder? classBuilder,
  }) : classBuilder = classBuilder ?? const PresenterClassBuilder();

  @override
  String get id => 'presenter';

  @override
  String get name => 'Presenter Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generatePresenter || config.generateVpc)) {
      return [];
    }
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final presenterName = '${entityName}Presenter';
    final fileName = '${entitySnake}_presenter.dart';

    final presenterDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(presenterDirPath, fileName);

    final repoFields = _buildRepoFields(config);
    final usecaseInfo = _buildUseCaseInfo(config, entityName, entityCamel);
    final usecaseFields = _buildUseCaseFields(usecaseInfo);
    final constructor = _buildConstructor(config, usecaseInfo);
    final methods = _buildMethods(config, usecaseInfo, entityName, entityCamel);
    final imports = _buildImports(config, usecaseInfo, entitySnake);

    final content = classBuilder.build(
      PresenterClassSpec(
        className: presenterName,
        fields: [...repoFields, ...usecaseFields],
        constructor: constructor,
        methods: methods,
        imports: imports,
      ),
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'presenter',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }

  List<Field> _buildRepoFields(GeneratorConfig config) {
    return config.effectiveRepos
        .map(
          (repo) => Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer(repo)
              ..name = StringUtils.pascalToCamel(repo),
          ),
        )
        .toList();
  }

  List<_UseCaseInfo> _buildUseCaseInfo(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
  ) {
    return config.methods
        .map((method) => _getUseCaseInfo(config, method, entityName, entityCamel))
        .toList();
  }

  List<Field> _buildUseCaseFields(List<_UseCaseInfo> useCases) {
    return useCases
        .map(
          (info) => Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..late = true
              ..type = refer(info.className)
              ..name = '_${info.fieldName}',
          ),
        )
        .toList();
  }

  _UseCaseInfo _getUseCaseInfo(
    GeneratorConfig config,
    String method,
    String entityName,
    String entityCamel,
  ) {
    switch (method) {
      case 'get':
        return _UseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get$entityName',
          presenterMethod: config.queryFieldType == 'NoParams'
              ? '''  Future<Result<$entityName, AppFailure>> get$entityName() {
    return _get$entityName.call(const NoParams());
  }'''
              : config.useZorphy
              ? '''  Future<Result<$entityName, AppFailure>> get$entityName(${config.queryFieldType} ${config.queryField}) {
    return _get$entityName.call(QueryParams<$entityName>(filter: Eq(${entityName}Fields.${config.queryField}, ${config.queryField})));
  }'''
              : '''  Future<Result<$entityName, AppFailure>> get$entityName(${config.queryFieldType} ${config.queryField}) {
    return _get$entityName.call(QueryParams<$entityName>(params: Params({'${config.queryField}': ${config.queryField}})));
  }''',
        );
      case 'getList':
        return _UseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}List',
          presenterMethod:
              '''  Future<Result<List<$entityName>, AppFailure>> get${entityName}List([ListQueryParams<$entityName> params = const ListQueryParams()]) {
    return _get${entityName}List.call(params);
  }''',
        );
      case 'create':
        return _UseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> create$entityName($entityName $entityCamel) {
    return _create$entityName.call($entityCamel);
  }''',
        );
      case 'update':
        final updateDataType = config.useZorphy
            ? '${entityName}Patch'
            : 'Partial<$entityName>';
        return _UseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> update$entityName(${config.idType} ${config.idField}, $updateDataType data) {
    return _update$entityName.call(UpdateParams<${config.idType}, $updateDataType>(id: ${config.idField}, data: ${config.useZorphy ? 'data' : 'Partial<$entityName>()'}));
  }''',
        );
      case 'delete':
        return _UseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete$entityName',
          presenterMethod:
              '''  Future<Result<void, AppFailure>> delete$entityName(${config.idType} ${config.idField}) {
    return _delete$entityName.call(DeleteParams<${config.idType}>(id: ${config.idField}));
  }''',
        );
      case 'watch':
        return _UseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch$entityName',
          presenterMethod: config.queryFieldType == 'NoParams'
              ? '''  Stream<Result<$entityName, AppFailure>> watch$entityName() {
    return _watch$entityName.call(const NoParams());
  }'''
              : config.useZorphy
              ? '''  Stream<Result<$entityName, AppFailure>> watch$entityName(${config.queryFieldType} ${config.queryField}) {
    return _watch$entityName.call(QueryParams<$entityName>(filter: Eq(${entityName}Fields.${config.queryField}, ${config.queryField})));
  }'''
              : '''  Stream<Result<$entityName, AppFailure>> watch$entityName(${config.queryFieldType} ${config.queryField}) {
    return _watch$entityName.call(QueryParams<$entityName>(params: Params({'${config.queryField}': ${config.queryField}})));
  }''',
        );
      case 'watchList':
        return _UseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}List',
          presenterMethod:
              '''  Stream<Result<List<$entityName>, AppFailure>> watch${entityName}List([ListQueryParams<$entityName> params = const ListQueryParams()]) {
    return _watch${entityName}List.call(params);
  }''',
        );
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  Constructor _buildConstructor(
    GeneratorConfig config,
    List<_UseCaseInfo> useCases,
  ) {
    final repoParams = config.effectiveRepos
        .map(
          (repo) => Parameter(
            (p) => p
              ..name = StringUtils.pascalToCamel(repo)
              ..toThis = true
              ..named = true
              ..required = true,
          ),
        )
        .toList();

    final mainRepo = config.effectiveRepos.isNotEmpty
        ? StringUtils.pascalToCamel(config.effectiveRepos.first)
        : 'repository';

    final registrations = useCases
        .map(
          (info) =>
              '_${info.fieldName} = registerUseCase(${info.className}($mainRepo));',
        )
        .join('\n');

    return Constructor(
      (c) => c
        ..optionalParameters.addAll(repoParams)
        ..body = Code(registrations),
    );
  }

  List<Method> _buildMethods(
    GeneratorConfig config,
    List<_UseCaseInfo> useCases,
    String entityName,
    String entityCamel,
  ) {
    final map = {for (final info in useCases) info.fieldName: info};
    final methods = <Method>[];
    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            _buildGetMethod(config, map['get$entityName']!, entityName),
          );
          break;
        case 'getList':
          methods.add(
            _buildGetListMethod(map['get${entityName}List']!, entityName),
          );
          break;
        case 'create':
          methods.add(
            _buildCreateMethod(
              map['create$entityName']!,
              entityName,
              entityCamel,
            ),
          );
          break;
        case 'update':
          methods.add(
            _buildUpdateMethod(config, map['update$entityName']!, entityName),
          );
          break;
        case 'delete':
          methods.add(_buildDeleteMethod(config, map['delete$entityName']!));
          break;
        case 'watch':
          methods.add(
            _buildWatchMethod(config, map['watch$entityName']!, entityName),
          );
          break;
        case 'watchList':
          methods.add(
            _buildWatchListMethod(map['watch${entityName}List']!, entityName),
          );
          break;
      }
    }
    return methods;
  }

  Method _buildGetMethod(
    GeneratorConfig config,
    _UseCaseInfo info,
    String entityName,
  ) {
    final methodName = info.fieldName;
    final body = config.queryFieldType == 'NoParams'
        ? 'return _$methodName.call(const NoParams(), cancelToken: cancelToken);'
        : config.useZorphy
        ? 'return _$methodName.call(QueryParams<$entityName>(filter: Eq(${entityName}Fields.${config.queryField}, ${config.queryField})), cancelToken: cancelToken);'
        : "return _$methodName.call(QueryParams<$entityName>(params: Params({'${config.queryField}': ${config.queryField}})), cancelToken: cancelToken);";

    return Method(
      (m) => m
        ..name = 'get$entityName'
        ..returns = refer('Future<Result<$entityName, AppFailure>>')
        ..requiredParameters.addAll(
          config.queryFieldType == 'NoParams'
              ? const []
              : [
                  Parameter(
                    (p) => p
                      ..name = config.queryField
                      ..type = refer(config.queryFieldType),
                  ),
                ],
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = Code(body),
    );
  }

  Method _buildGetListMethod(_UseCaseInfo info, String entityName) {
    return Method(
      (m) => m
        ..name = 'get${entityName}List'
        ..returns = refer('Future<Result<List<$entityName>, AppFailure>>')
        ..optionalParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>')
              ..defaultTo = Code('const ListQueryParams()'),
          ),
          _cancelTokenParam(),
        ])
        ..body = Code(
          'return _${info.fieldName}.call(params, cancelToken: cancelToken);',
        ),
    );
  }

  Method _buildCreateMethod(
    _UseCaseInfo info,
    String entityName,
    String entityCamel,
  ) {
    return Method(
      (m) => m
        ..name = 'create$entityName'
        ..returns = refer('Future<Result<$entityName, AppFailure>>')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = entityCamel
              ..type = refer(entityName),
          ),
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = Code(
          'return _${info.fieldName}.call($entityCamel, cancelToken: cancelToken);',
        ),
    );
  }

  Method _buildUpdateMethod(
    GeneratorConfig config,
    _UseCaseInfo info,
    String entityName,
  ) {
    final dataType = config.useZorphy
        ? '${entityName}Patch'
        : 'Partial<$entityName>';
    final dataValue = config.useZorphy ? 'data' : 'Partial<$entityName>()';
    return Method(
      (m) => m
        ..name = 'update$entityName'
        ..returns = refer('Future<Result<$entityName, AppFailure>>')
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = config.idField
              ..type = refer(config.idType),
          ),
          Parameter(
            (p) => p
              ..name = 'data'
              ..type = refer(dataType),
          ),
        ])
        ..optionalParameters.add(_cancelTokenParam())
        ..body = Code(
          'return _${info.fieldName}.call(UpdateParams<${config.idType}, $dataType>(id: ${config.idField}, data: $dataValue), cancelToken: cancelToken);',
        ),
    );
  }

  Method _buildDeleteMethod(GeneratorConfig config, _UseCaseInfo info) {
    return Method(
      (m) => m
        ..name = 'delete${config.name}'
        ..returns = refer('Future<Result<void, AppFailure>>')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = config.idField
              ..type = refer(config.idType),
          ),
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = Code(
          'return _${info.fieldName}.call(DeleteParams<${config.idType}>(id: ${config.idField}), cancelToken: cancelToken);',
        ),
    );
  }

  Method _buildWatchMethod(
    GeneratorConfig config,
    _UseCaseInfo info,
    String entityName,
  ) {
    final methodName = info.fieldName;
    final body = config.queryFieldType == 'NoParams'
        ? 'return _$methodName.call(const NoParams(), cancelToken: cancelToken);'
        : config.useZorphy
        ? 'return _$methodName.call(QueryParams<$entityName>(filter: Eq(${entityName}Fields.${config.queryField}, ${config.queryField})), cancelToken: cancelToken);'
        : "return _$methodName.call(QueryParams<$entityName>(params: Params({'${config.queryField}': ${config.queryField}})), cancelToken: cancelToken);";

    return Method(
      (m) => m
        ..name = 'watch$entityName'
        ..returns = refer('Stream<Result<$entityName, AppFailure>>')
        ..requiredParameters.addAll(
          config.queryFieldType == 'NoParams'
              ? const []
              : [
                  Parameter(
                    (p) => p
                      ..name = config.queryField
                      ..type = refer(config.queryFieldType),
                  ),
                ],
        )
        ..optionalParameters.add(_cancelTokenParam())
        ..body = Code(body),
    );
  }

  Method _buildWatchListMethod(_UseCaseInfo info, String entityName) {
    return Method(
      (m) => m
        ..name = 'watch${entityName}List'
        ..returns = refer('Stream<Result<List<$entityName>, AppFailure>>')
        ..optionalParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>')
              ..defaultTo = Code('const ListQueryParams()'),
          ),
          _cancelTokenParam(),
        ])
        ..body = Code(
          'return _${info.fieldName}.call(params, cancelToken: cancelToken);',
        ),
    );
  }

  Parameter _cancelTokenParam() {
    return Parameter(
      (p) => p
        ..name = 'cancelToken'
        ..type = refer('CancelToken?'),
    );
  }

  List<String> _buildImports(
    GeneratorConfig config,
    List<_UseCaseInfo> useCases,
    String entitySnake,
  ) {
    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '../../../domain/entities/$entitySnake/$entitySnake.dart',
    ];

    for (final repo in config.effectiveRepos) {
      final repoSnake = StringUtils.camelToSnake(
        repo.replaceAll('Repository', ''),
      );
      imports.add('../../../domain/repositories/${repoSnake}_repository.dart');
    }

    for (final info in useCases) {
      final usecaseSnake = StringUtils.camelToSnake(
        info.className.replaceAll('UseCase', ''),
      );
      imports.add(
        '../../../domain/usecases/$entitySnake/${usecaseSnake}_usecase.dart',
      );
    }

    return imports;
  }
}

class _UseCaseInfo {
  final String className;
  final String fieldName;
  final String presenterMethod;

  _UseCaseInfo({
    required this.className,
    required this.fieldName,
    required this.presenterMethod,
  });
}
