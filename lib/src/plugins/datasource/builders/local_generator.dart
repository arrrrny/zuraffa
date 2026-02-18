import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/generator_options.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/plugin_system/plugin_action.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

part 'local_crud_methods.dart';
part 'local_helper_methods.dart';
part 'local_stream_methods.dart';

/// Generates local data source implementations.
class LocalDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;

  LocalDataSourceBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = _buildMethods(config);
    final fields = _buildFields(config);
    final constructors = _buildConstructors(config);
    final importPaths = _buildImportPaths(config);

    final directives = _buildDirectives(importPaths, config);

    final clazz = Class(
      (b) => b
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    if (config.action == PluginAction.delete) {
      return FileUtils.deleteFile(
        filePath,
        'datasource_local',
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

    if (File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();

      if (config.action == PluginAction.remove) {
        // Filter methods to remove based on config.methods
        final methodsToRemove = methods.where((m) => config.methods.contains(m.name)).toList();
        final reverted = _removeMethods(
          source: existing,
          className: dataSourceName,
          methods: methodsToRemove,
        );
        return FileUtils.writeFile(
          filePath,
          reverted,
          'datasource_local',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }

      if (config.action == PluginAction.add ||
          config.action == PluginAction.create) {
        if (config.action == PluginAction.create && options.force) {
          // Fall through to write new file logic
        } else {
          final importLines = _buildImportLines(importPaths);
          final mergedImports = _mergeImports(existing, importLines);
          
          // Filter methods to add based on config.methods
          final methodsToAdd = methods.where((m) => config.methods.contains(m.name)).toList();
          
          final appended = _appendMethods(
            source: mergedImports,
            className: dataSourceName,
            methods: methodsToAdd,
          );
          return FileUtils.writeFile(
            filePath,
            appended,
            'datasource_local',
            force: true,
            dryRun: options.dryRun,
            verbose: options.verbose,
            revert: false,
          );
        }
      }
    }

    if (config.action == PluginAction.remove) {
      return GeneratedFile(path: filePath, type: 'datasource_local', action: 'skipped');
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'local_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  String _removeMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    final helper = const AstHelper();
    for (final method in methods) {
      final methodName = method.name!;
      updated = helper.removeMethodFromClass(
        source: updated,
        className: className,
        methodName: methodName,
      );
    }
    return updated;
  }

  String _appendMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    for (final method in methods) {
      final methodSource = _emitMethod(method);
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: updated,
          className: className,
          memberSource: methodSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _mergeImports(String source, List<String> imports) {
    var updated = source;
    for (final importLine in imports) {
      if (!updated.contains(importLine)) {
        updated = '$importLine\n$updated';
      }
    }
    return updated;
  }

  List<String> _buildImportLines(List<String> importPaths) {
    return importPaths.map((path) => "import '$path';").toList();
  }

  String _emitMethod(Method method) {
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    return method.accept(emitter).toString();
  }

  List<String> _buildImportPaths(GeneratorConfig config) {
    final entitySnake = config.nameSnake;
    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final imports = <String>[];
    
    if (useHive) {
      imports.add('package:hive_ce_flutter/hive_ce_flutter.dart');
    }
    imports.add('package:zuraffa/zuraffa.dart');
    imports.add('../../../domain/entities/$entitySnake/$entitySnake.dart');
    imports.add('${entitySnake}_datasource.dart');
    
    return imports;
  }

  List<Directive> _buildDirectives(List<String> importPaths, GeneratorConfig config) {
    return importPaths.map(Directive.import).toList();
  }

  List<Field> _buildFields(GeneratorConfig config) {
    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final fields = <Field>[];
    final entityName = config.name;

    if (useHive) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('Box<$entityName>')
            ..name = '_box',
        ),
      );
    }
    return fields;
  }

  List<Constructor> _buildConstructors(GeneratorConfig config) {
    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final constructors = <Constructor>[];

    if (useHive) {
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
    }
    return constructors;
  }

  List<Method> _buildMethods(GeneratorConfig config) {
    final methods = <Method>[];
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final dataSourceName = '${entityName}LocalDataSource';
    final useHive = config.generateLocal || config.cacheStorage == 'hive';

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Initializing $dataSourceName'),
                  ]).statement,
                )
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('$dataSourceName initialized'),
                  ]).statement,
                ),
            ),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Stream<bool>')
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('Stream')
                      .property('value')
                      .call([literalBool(true)])
                      .returned
                      .statement,
                ),
            ),
        ),
      );
    }

    if (useHive) {
      final hasListMethods = config.methods.any(
        (m) => m == 'getList' || m == 'watchList',
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
                  refer('_box').property('values').property('query').call([
                    refer('params'),
                  ]),
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
                      'UpdateParams<${config.idType}, $dataType>',
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
                      'UpdateParams<${config.idType}, $dataType>',
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
                  _param('params', 'DeleteParams<${config.idType}>'),
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
            methods.add(
              _buildMethodWithBody(
                name: method,
                returnType: 'Future<void>',
                parameters: [_param('params', 'dynamic')],
                body: Block(
                  (b) => b
                    ..statements.add(
                      refer('throw UnimplementedError').call([
                        literalString('Implement local $method'),
                      ]).statement,
                    ),
                ),
                isAsync: true,
                override: true,
              ),
            );
        }
      }
    } else {
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
      if (config.idType != 'NoParams') {
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
                  _param('params', 'UpdateParams<${config.idType}, $dataType>'),
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
                  _param('params', 'DeleteParams<${config.idType}>'),
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
    return methods;
  }

}
