import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/presenter_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/presenter_class_builder.dart';

class PresenterPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
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
  Command createCommand() => PresenterCommand(this);

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generatePresenter || config.generateVpc)) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = PresenterPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        classBuilder: classBuilder,
      );
      return delegator.generate(config);
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

    final useDi = config.generateDi;
    final repoFields = useDi ? [] : _buildRepoFields(config);
    final usecaseInfo = _buildUseCaseInfo(config, entityName);
    final usecaseFields = _buildUseCaseFields(usecaseInfo);
    final constructor = _buildConstructor(config, usecaseInfo, useDi);
    final methods = _buildMethods(config, usecaseInfo, entityName, entityCamel);
    final imports = _buildImports(config, usecaseInfo, entitySnake, useDi);

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
  ) {
    return config.methods
        .map((method) => _getUseCaseInfo(method, entityName))
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

  _UseCaseInfo _getUseCaseInfo(String method, String entityName) {
    switch (method) {
      case 'get':
        return _UseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get$entityName',
        );
      case 'list':
      case 'getList':
        return _UseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}List',
        );
      case 'create':
        return _UseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create$entityName',
        );
      case 'update':
        return _UseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update$entityName',
        );
      case 'delete':
        return _UseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete$entityName',
        );
      case 'watch':
        return _UseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch$entityName',
        );
      case 'watchList':
        return _UseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}List',
        );
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  Constructor _buildConstructor(
    GeneratorConfig config,
    List<_UseCaseInfo> useCases,
    bool useDi,
  ) {
    final registrations = <Code>[];

    if (useDi) {
      for (final info in useCases) {
        registrations.add(
          refer('_${info.fieldName}')
              .assign(
                refer('registerUseCase').call([
                  refer('getIt').call([], {}, [refer(info.className)]),
                ]),
              )
              .statement,
        );
      }

      return Constructor(
        (c) => c..body = Block((b) => b..statements.addAll(registrations)),
      );
    }

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

    for (final info in useCases) {
      registrations.add(
        refer('_${info.fieldName}')
            .assign(
              refer('registerUseCase').call([
                refer(info.className).call([refer(mainRepo)]),
              ]),
            )
            .statement,
      );
    }

    return Constructor(
      (c) => c
        ..optionalParameters.addAll(repoParams)
        ..body = Block((b) => b..statements.addAll(registrations)),
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
          final info = map['get$entityName'];
          if (info == null) {
            throw ArgumentError('Missing get$entityName use case info');
          }
          methods.add(_buildGetMethod(config, info, entityName));
          break;
        case 'getList':
          final info = map['get${entityName}List'];
          if (info == null) {
            throw ArgumentError('Missing get${entityName}List use case info');
          }
          methods.add(_buildGetListMethod(info, entityName));
          break;
        case 'create':
          final info = map['create$entityName'];
          if (info == null) {
            throw ArgumentError('Missing create$entityName use case info');
          }
          methods.add(_buildCreateMethod(info, entityName, entityCamel));
          break;
        case 'update':
          final info = map['update$entityName'];
          if (info == null) {
            throw ArgumentError('Missing update$entityName use case info');
          }
          methods.add(_buildUpdateMethod(config, info, entityName));
          break;
        case 'delete':
          final info = map['delete$entityName'];
          if (info == null) {
            throw ArgumentError('Missing delete$entityName use case info');
          }
          methods.add(_buildDeleteMethod(config, info));
          break;
        case 'watch':
          final info = map['watch$entityName'];
          if (info == null) {
            throw ArgumentError('Missing watch$entityName use case info');
          }
          methods.add(_buildWatchMethod(config, info, entityName));
          break;
        case 'watchList':
          final info = map['watch${entityName}List'];
          if (info == null) {
            throw ArgumentError('Missing watch${entityName}List use case info');
          }
          methods.add(_buildWatchListMethod(info, entityName));
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
    final paramsExpression = config.queryFieldType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : config.useZorphy
        ? refer('QueryParams<$entityName>').call([], {
            'filter': refer('Eq').call([
              refer('${entityName}Fields').property(config.queryField),
              refer(config.queryField),
            ]),
          })
        : refer('QueryParams<$entityName>').call([], {
            'params': refer('Params').call([
              literalMap({config.queryField: refer(config.queryField)}),
            ]),
          });

    final callExpression = refer('_$methodName')
        .property('call')
        .call([paramsExpression], {'cancelToken': refer('cancelToken')});

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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
        ),
    );
  }

  Method _buildGetListMethod(_UseCaseInfo info, String entityName) {
    final callExpression = refer('_${info.fieldName}')
        .property('call')
        .call([refer('params')], {'cancelToken': refer('cancelToken')});

    return Method(
      (m) => m
        ..name = 'get${entityName}List'
        ..returns = refer('Future<Result<List<$entityName>, AppFailure>>')
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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
        ),
    );
  }

  Method _buildCreateMethod(
    _UseCaseInfo info,
    String entityName,
    String entityCamel,
  ) {
    final callExpression = refer('_${info.fieldName}')
        .property('call')
        .call([refer(entityCamel)], {'cancelToken': refer('cancelToken')});

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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
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
    final updateParams = refer(
      'UpdateParams<${config.idType}, $dataType>',
    ).call([], {'id': refer(config.idField), 'data': refer('data')});
    final callExpression = refer('_${info.fieldName}')
        .property('call')
        .call([updateParams], {'cancelToken': refer('cancelToken')});

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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
        ),
    );
  }

  Method _buildDeleteMethod(GeneratorConfig config, _UseCaseInfo info) {
    final deleteParams = refer(
      'DeleteParams<${config.idType}>',
    ).call([], {'id': refer(config.idField)});
    final callExpression = refer('_${info.fieldName}')
        .property('call')
        .call([deleteParams], {'cancelToken': refer('cancelToken')});

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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
        ),
    );
  }

  Method _buildWatchMethod(
    GeneratorConfig config,
    _UseCaseInfo info,
    String entityName,
  ) {
    final methodName = info.fieldName;
    final paramsExpression = config.queryFieldType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : config.useZorphy
        ? refer('QueryParams<$entityName>').call([], {
            'filter': refer('Eq').call([
              refer('${entityName}Fields').property(config.queryField),
              refer(config.queryField),
            ]),
          })
        : refer('QueryParams<$entityName>').call([], {
            'params': refer('Params').call([
              literalMap({config.queryField: refer(config.queryField)}),
            ]),
          });

    final callExpression = refer('_$methodName')
        .property('call')
        .call([paramsExpression], {'cancelToken': refer('cancelToken')});

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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
        ),
    );
  }

  Method _buildWatchListMethod(_UseCaseInfo info, String entityName) {
    final callExpression = refer('_${info.fieldName}')
        .property('call')
        .call([refer('params')], {'cancelToken': refer('cancelToken')});

    return Method(
      (m) => m
        ..name = 'watch${entityName}List'
        ..returns = refer('Stream<Result<List<$entityName>, AppFailure>>')
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
        ..body = Block(
          (b) => b..statements.add(callExpression.returned.statement),
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
    bool useDi,
  ) {
    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '../../../domain/entities/$entitySnake/$entitySnake.dart',
    ];

    if (useDi) {
      imports.add('../../../di/service_locator.dart');
    } else {
      for (final repo in config.effectiveRepos) {
        final repoSnake = StringUtils.camelToSnake(
          repo.replaceAll('Repository', ''),
        );
        imports.add(
          '../../../domain/repositories/${repoSnake}_repository.dart',
        );
      }
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

  _UseCaseInfo({required this.className, required this.fieldName});
}
