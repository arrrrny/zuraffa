import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/presenter_command.dart';
import '../../core/builder/patterns/common_patterns.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../models/parsed_usecase_info.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/presenter_class_builder.dart';
import 'capabilities/create_presenter_capability.dart';

class PresenterPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final PresenterClassBuilder classBuilder;

  PresenterPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const PresenterClassBuilder(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [CreatePresenterCapability(this)];

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
    if (!(config.generatePresenter || config.generateVpcs)) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = PresenterPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        classBuilder: classBuilder,
      );
      return delegator.generate(config);
    }

    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final presenterName = config.effectivePresenterName;
    final fileName = '${entitySnake}_presenter.dart';

    final domainSnake = config.effectiveDomain;
    final presenterDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    );
    final filePath = path.join(presenterDirPath, fileName);

    final useDi = config.generateDi;
    final repoFields = useDi ? [] : _buildRepoFields(config);
    final usecaseInfo = _buildUseCaseInfo(config, entityName);
    final usecaseFields = _buildUseCaseFields(usecaseInfo);
    final constructor = _buildConstructor(config, usecaseInfo, useDi);
    final methods = _buildMethods(config, usecaseInfo, entityName, entityCamel);
    final imports = _buildImports(config, usecaseInfo, domainSnake, useDi);

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
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
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

  List<ParsedUseCaseInfo> _buildUseCaseInfo(
    GeneratorConfig config,
    String entityName,
  ) {
    final infos = <ParsedUseCaseInfo>[];

    // Entity-based usecases
    if (!config.noEntity) {
      for (final method in config.methods) {
        infos.add(_getUseCaseInfo(method, entityName));
      }
    }

    // Custom usecases
    if (config.isOrchestrator) {
      infos.addAll(
        config.usecases.map((u) {
          return CommonPatterns.parseUseCaseInfo(u, config, outputDir);
        }),
      );
    } else if (config.isCustomUseCase &&
        config.methods.isEmpty &&
        !config.noEntity) {
      infos.add(
        ParsedUseCaseInfo(
          className: '${config.name}UseCase',
          fieldName: config.nameCamel,
        ),
      );
    }

    return infos;
  }

  List<Field> _buildUseCaseFields(List<ParsedUseCaseInfo> useCases) {
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

  ParsedUseCaseInfo _getUseCaseInfo(String method, String entityName) {
    switch (method) {
      case 'get':
        return ParsedUseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get$entityName',
        );
      case 'list':
      case 'getList':
        return ParsedUseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}List',
        );
      case 'create':
        return ParsedUseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create$entityName',
        );
      case 'update':
        return ParsedUseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update$entityName',
        );
      case 'delete':
        return ParsedUseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete$entityName',
        );
      case 'watch':
        return ParsedUseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch$entityName',
        );
      case 'watchList':
        return ParsedUseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}List',
        );
      default:
        return ParsedUseCaseInfo(
          className: '${StringUtils.capitalize(method)}${entityName}UseCase',
          fieldName: '$method$entityName',
        );
    }
  }

  Constructor _buildConstructor(
    GeneratorConfig config,
    List<ParsedUseCaseInfo> useCases,
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
        : (config.hasService
              ? StringUtils.pascalToCamel(config.effectiveService!)
              : 'repository');

    for (final info in useCases) {
      registrations.add(
        refer('_${info.fieldName}')
            .assign(
              refer('registerUseCase').call([
                refer(info.className).call([
                  if (config.effectiveRepos.isNotEmpty || config.hasService)
                    refer(mainRepo),
                ]),
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
    List<ParsedUseCaseInfo> useCases,
    String entityName,
    String entityCamel,
  ) {
    final methods = <Method>[];
    final map = {for (final info in useCases) info.fieldName: info};

    // 1. Entity-based methods
    for (final method in config.methods) {
      final fieldName = switch (method) {
        'get' => 'get$entityName',
        'list' || 'getList' => 'get${entityName}List',
        'create' => 'create$entityName',
        'update' => 'update$entityName',
        'delete' => 'delete$entityName',
        'watch' => 'watch$entityName',
        'watchList' => 'watch${entityName}List',
        _ => '$method$entityName',
      };

      final info = map[fieldName];
      if (info == null) continue;

      switch (method) {
        case 'get':
          methods.add(_buildGetMethod(config, info, entityName));
          break;
        case 'list':
        case 'getList':
          methods.add(_buildGetListMethod(info, entityName));
          break;
        case 'create':
          methods.add(_buildCreateMethod(info, entityName, entityCamel));
          break;
        case 'update':
          methods.add(_buildUpdateMethod(config, info, entityName));
          break;
        case 'delete':
          methods.add(_buildDeleteMethod(config, info));
          break;
        case 'watch':
          methods.add(_buildWatchMethod(config, info, entityName));
          break;
        case 'watchList':
          methods.add(_buildWatchListMethod(info, entityName));
          break;
      }
    }

    // 2. Custom methods
    if (config.isOrchestrator) {
      for (final u in config.usecases) {
        final info = CommonPatterns.parseUseCaseInfo(u, config, outputDir);
        methods.add(_buildCustomMethod(config, info));
      }
    } else if (config.isCustomUseCase && config.methods.isEmpty) {
      methods.add(_buildCustomMethod(config, useCases.first));
    }

    return methods;
  }

  Method _buildCustomMethod(GeneratorConfig config, ParsedUseCaseInfo info) {
    final returns = info.returnsType ?? config.returnsType ?? 'void';
    final params = info.paramsType ?? config.paramsType ?? 'NoParams';
    final isStream = (info.useCaseType ?? config.useCaseType) == 'stream';

    // Parse nullability
    final isNullable = returns.endsWith('?');
    final baseReturns = isNullable
        ? returns.substring(0, returns.length - 1)
        : returns;

    final resultType = TypeReference(
      (b) => b
        ..symbol = 'Result'
        ..types.addAll([
          TypeReference(
            (b) => b
              ..symbol = baseReturns
              ..isNullable = isNullable,
          ),
          refer('AppFailure'),
        ]),
    );

    final returnType = TypeReference(
      (b) => b
        ..symbol = isStream ? 'Stream' : 'Future'
        ..types.add(resultType),
    );

    return Method(
      (m) => m
        ..name = info.fieldName
        ..returns = returnType
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
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('_${info.fieldName}')
                  .property('call')
                  .call(
                    [
                      if (params != 'NoParams')
                        refer('params')
                      else
                        refer('NoParams').constInstance([]),
                    ],
                    {'cancelToken': refer('cancelToken')},
                  )
                  .returned
                  .statement,
            ),
        ),
    );
  }

  Method _buildGetMethod(
    GeneratorConfig config,
    ParsedUseCaseInfo info,
    String entityName,
  ) {
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
            'params': literalMap({config.queryField: refer(config.queryField)}),
          });

    final callExpression = refer('_${info.fieldName}')
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

  Method _buildGetListMethod(ParsedUseCaseInfo info, String entityName) {
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
    ParsedUseCaseInfo info,
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
    ParsedUseCaseInfo info,
    String entityName,
  ) {
    // Use Patch for entity-based updates by default
    final dataType = '${entityName}Patch';
    final updateParams = refer(
      'UpdateParams<${config.idFieldType}, $dataType>',
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
              ..type = refer(config.idFieldType),
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

  Method _buildDeleteMethod(GeneratorConfig config, ParsedUseCaseInfo info) {
    final deleteParams = refer(
      'DeleteParams<${config.idFieldType}>',
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
              ..type = refer(config.idFieldType),
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
    ParsedUseCaseInfo info,
    String entityName,
  ) {
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
            'params': literalMap({config.queryField: refer(config.queryField)}),
          });

    final callExpression = refer('_${info.fieldName}')
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

  Method _buildWatchListMethod(ParsedUseCaseInfo info, String entityName) {
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
    List<ParsedUseCaseInfo> useCases,
    String domainSnake,
    bool useDi,
  ) {
    final imports = <String>['package:zuraffa/zuraffa.dart'];

    if (config.isCustomUseCase || config.isOrchestrator) {
      final types = <String>[];
      if (!config.noEntity) {
        types.add(config.name);
      }
      // Only add types that are explicitly used in the presenter class (fields/params)
      if (config.returnsType != null) {
        types.addAll(CommonPatterns.extractBaseTypes(config.returnsType!));
      }
      if (config.paramsType != null) {
        types.addAll(CommonPatterns.extractBaseTypes(config.paramsType!));
      }
      for (final info in useCases) {
        // We DO need types used in field types and method signatures
        if (info.paramsType != null) {
          types.addAll(CommonPatterns.extractBaseTypes(info.paramsType!));
        }
        if (info.returnsType != null) {
          types.addAll(CommonPatterns.extractBaseTypes(info.returnsType!));
        }
      }

      final entityImports = CommonPatterns.entityImports(
        types,
        config,
        depth: 3,
      );
      imports.addAll(entityImports);
    } else {
      imports.add('../../../domain/entities/$domainSnake/$domainSnake.dart');
    }

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
      final usecaseDomain = CommonPatterns.findUseCaseDomain(
        usecaseSnake,
        domainSnake,
        outputDir,
      );
      imports.add(
        '../../../domain/usecases/$usecaseDomain/${usecaseSnake}_usecase.dart',
      );

      if (info.paramsType != null || info.returnsType != null) {
        final types = <String>[];
        if (info.paramsType != null) types.add(info.paramsType!);
        if (info.returnsType != null) types.add(info.returnsType!);
        final entityImports = CommonPatterns.entityImports(
          types,
          config,
          depth: 3,
        );
        imports.addAll(entityImports);
      }
    }

    return imports.toList();
  }
}
