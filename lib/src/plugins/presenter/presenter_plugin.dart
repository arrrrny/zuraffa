import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart' as analyzer;
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/presenter_command.dart';
import '../../core/ast/append_executor.dart';
import '../../core/ast/ast_modifier.dart';
import '../../core/ast/file_parser.dart';
import '../../core/ast/node_finder.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_action.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/presenter_class_builder.dart';
import 'capabilities/create_presenter_capability.dart';

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
  List<ZuraffaCapability> get capabilities => [
        CreatePresenterCapability(this),
      ];

  @override
  String get id => 'presenter';

  @override
  String get name => 'Presenter Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => PresenterCommand(this);

  @override
  Future<List<GeneratedFile>> create(GeneratorConfig config) =>
      _dispatch(config, PluginAction.create);

  @override
  Future<List<GeneratedFile>> delete(GeneratorConfig config) =>
      _dispatch(config, PluginAction.delete);

  @override
  Future<List<GeneratedFile>> add(GeneratorConfig config) =>
      _dispatch(config, PluginAction.add);

  @override
  Future<List<GeneratedFile>> remove(GeneratorConfig config) =>
      _dispatch(config, PluginAction.remove);

  Future<List<GeneratedFile>> _dispatch(
    GeneratorConfig config,
    PluginAction action,
  ) async {
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
      return delegator._dispatch(config, action);
    }

    switch (action) {
      case PluginAction.create:
        return generate(config);
      case PluginAction.delete:
        return _delete(config);
      case PluginAction.add:
        return _add(config);
      case PluginAction.remove:
        return _remove(config);
    }
  }

  Future<List<GeneratedFile>> _remove(GeneratorConfig config) async {
    final entitySnake = config.nameSnake;
    final fileName = '${entitySnake}_presenter.dart';
    final presenterDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(presenterDirPath, fileName);
    final file = File(filePath);

    if (!file.existsSync()) {
      return [];
    }

    var source = await file.readAsString();
    final originalSource = source;

    // Identify use cases to remove
    final useCases = _buildUseCaseInfo(config, config.name);
    
    final parseResult = await FileParser().parseFile(filePath);
    if (parseResult.unit == null) return [];

    final classNode = NodeFinder.findClass(parseResult.unit!, '${config.name}Presenter');
    if (classNode == null) return [];

    final nodesToRemove = <analyzer.AstNode>[];

    for (final info in useCases) {
      // Find method
      for (final member in classNode.members) {
        if (member is analyzer.MethodDeclaration &&
            member.name.lexeme == info.fieldName) {
          nodesToRemove.add(member);
        } else if (member is analyzer.FieldDeclaration) {
          final fieldName = '_${info.fieldName}';
          if (member.fields.variables.any((v) => v.name.lexeme == fieldName)) {
            nodesToRemove.add(member);
          }
        }
      }

      // Find imports
      final usecaseSnake = StringUtils.camelToSnake(
        info.className.replaceAll('UseCase', ''),
      );
      final useCaseFileName = '${usecaseSnake}_usecase.dart';
      for (final directive in parseResult.unit!.directives) {
        if (directive is analyzer.ImportDirective &&
            directive.uri.stringValue?.endsWith(useCaseFileName) == true) {
          nodesToRemove.add(directive);
        }
      }

      // Find constructor statements
      for (final member in classNode.members) {
        if (member is analyzer.ConstructorDeclaration) {
          final body = member.body;
          if (body is analyzer.BlockFunctionBody) {
            for (final statement in body.block.statements) {
              if (statement is analyzer.ExpressionStatement) {
                final expression = statement.expression;
                if (expression is analyzer.AssignmentExpression) {
                  final lhs = expression.leftHandSide;
                  if (lhs is analyzer.SimpleIdentifier &&
                      lhs.name == '_${info.fieldName}') {
                    nodesToRemove.add(statement);
                  }
                }
              }
            }
          }
        }
      }
    }

    // Sort descending to remove safely
    nodesToRemove.sort((a, b) => b.offset.compareTo(a.offset));

    // Remove duplicates if any (though unlikely with this logic)
    final uniqueNodes = nodesToRemove.toSet().toList();
    uniqueNodes.sort((a, b) => b.offset.compareTo(a.offset));

    for (final node in uniqueNodes) {
      source = source.substring(0, node.offset) + source.substring(node.end);
    }

    if (source != originalSource) {
      await FileUtils.writeFile(
        filePath,
        source,
        'presenter',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        revert: false, // Do not delete file when removing members
      );
      return [
        GeneratedFile(path: filePath, type: 'presenter', action: 'updated'),
      ];
    }
    return [];
  }

  Future<List<GeneratedFile>> _add(GeneratorConfig config) async {
    final entitySnake = config.nameSnake;
    final fileName = '${entitySnake}_presenter.dart';
    final presenterDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(presenterDirPath, fileName);
    final file = File(filePath);

    if (!file.existsSync()) {
      return [];
    }

    var source = await file.readAsString();
    final originalSource = source;
    final executor = AppendExecutor();

    // Identify use cases
    final useCases = _buildUseCaseInfo(config, config.name);
    
    final parseResult = await FileParser().parseFile(filePath);
    final classNode = NodeFinder.findClass(parseResult.unit!, '${config.name}Presenter');
    if (classNode == null) return [];
    
    final existingMembers = classNode.members.map((m) {
        if (m is analyzer.FieldDeclaration) {
            return m.fields.variables.first.name.lexeme;
        } else if (m is analyzer.MethodDeclaration) {
            return m.name.lexeme;
        }
        return '';
    }).toSet();

    for (final info in useCases) {
      // Check if field exists
      final fieldName = '_${info.fieldName}';
      if (existingMembers.contains(fieldName)) continue;
      
      // Add import
      final usecaseSnake = StringUtils.camelToSnake(
        info.className.replaceAll('UseCase', ''),
      );
      final useCaseFileName = '${usecaseSnake}_usecase.dart';
      final importPath = '../../../domain/usecases/$entitySnake/$useCaseFileName';
      
      var result = executor.execute(AppendRequest.import(
        source: source,
        importPath: importPath,
      ));
      if (result.changed) source = result.source;

      // Add field
      final fieldSource = 'late final ${info.className} $fieldName = registerUseCase(getIt<${info.className}>());';
      result = executor.execute(AppendRequest.field(
        source: source,
        className: '${config.name}Presenter',
        memberSource: fieldSource,
      ));
      if (result.changed) source = result.source;

      // Add method
      if (!existingMembers.contains(info.fieldName)) {
          final methodSource = '''
  Future<Result<void, AppFailure>> ${info.fieldName}() async {
    // TODO: Implement ${info.fieldName}
    throw UnimplementedError();
  }''';
          result = executor.execute(AppendRequest.method(
            source: source,
            className: '${config.name}Presenter',
            memberSource: methodSource,
          ));
          if (result.changed) source = result.source;
      }
    }

    if (source != originalSource) {
      await FileUtils.writeFile(
        filePath,
        source,
        'presenter',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return [GeneratedFile(path: filePath, type: 'presenter', action: 'updated')];
    }
    return [];
  }

  /// Generates presenter files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated presenter files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generatePresenter || config.generateVpcs)) {
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
      revert: config.revert,
    );
    return [file];
  }

  Future<List<GeneratedFile>> _delete(GeneratorConfig config) async {
    final entitySnake = config.nameSnake;
    final fileName = '${entitySnake}_presenter.dart';
    final presenterDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(presenterDirPath, fileName);
    final file = File(filePath);

    if (!file.existsSync()) {
      return [];
    }

    if (!dryRun) {
      await file.delete();
    }

    return [
      GeneratedFile(path: filePath, type: 'presenter', action: 'deleted'),
    ];
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
        // Handle custom use cases
        // Assumes method name is the use case name without 'UseCase' suffix if provided
        // e.g. 'activateProduct' -> ActivateProductUseCase, _activateProduct
        final useCaseName = StringUtils.convertToPascalCase(method);
        final className = '${useCaseName}UseCase';
        final fieldName = StringUtils.pascalToCamel(useCaseName);
        return _UseCaseInfo(
          className: className,
          fieldName: fieldName,
        );
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
        default:
          final useCaseName = StringUtils.convertToPascalCase(method);
          final fieldName = StringUtils.pascalToCamel(useCaseName);
          final info = map[fieldName];
          if (info != null) {
            methods.add(_buildCustomMethod(info));
          }
          break;
      }
    }
    return methods;
  }

  Method _buildCustomMethod(_UseCaseInfo info) {
    return Method(
      (m) => m
        ..name = info.fieldName
        ..returns = refer('Future<Result<void, AppFailure>>')
        ..modifier = MethodModifier.async
        ..body = Block(
          (b) => b
            ..statements.add(Code('// TODO: Implement ${info.fieldName}'))
            ..statements.add(Code('throw UnimplementedError();')),
        ),
    );
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
            'params': literalMap({config.queryField: refer(config.queryField)}),
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
            'params': literalMap({config.queryField: refer(config.queryField)}),
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
