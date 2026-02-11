import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class LocalDataSourceBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  LocalDataSourceBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_data_source.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'data_sources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final methods = <Method>[];
    final fields = <Field>[];
    final constructors = <Constructor>[];

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
                  refer('_box')
                      .property('values')
                      .property('query')
                      .call([refer('params')]),
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
                        refer('_box')
                            .property('delete')
                            .call([literalString(entitySnake)]),
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
                body: _buildWatchBody(),
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
                body: _buildWatchListBody(),
                isAsync: false,
              ),
            );
            break;
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

    final clazz = Class(
      (b) => b
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );

    final directives = <Directive>[
      if (useHive)
        Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('${entitySnake}_data_source.dart'),
    ];

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'local_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Method _buildMethodWithBody({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
    required Code body,
    required bool isAsync,
    bool override = true,
    MethodModifier? modifier,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..annotations.addAll(override ? [CodeExpression(Code('override'))] : [])
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..modifier = modifier ?? (isAsync ? MethodModifier.async : null)
        ..body = body,
    );
  }

  Block _returnBody(Expression expression) {
    return Block(
      (b) => b..statements.add(expression.returned.statement),
    );
  }

  Block _awaitBody(Expression expression) {
    return Block(
      (b) => b..statements.add(expression.awaited.statement),
    );
  }

  Block _awaitThenReturn(Expression awaitExpression, Expression returnExpression) {
    return Block(
      (b) => b
        ..statements.add(awaitExpression.awaited.statement)
        ..statements.add(returnExpression.returned.statement),
    );
  }

  Block _throwBody(String message) {
    return Block(
      (b) => b
        ..statements.add(
          refer('UnimplementedError')
              .call([literalString(message)])
              .thrown
              .statement,
        ),
    );
  }

  Block _buildSaveAllBody(String idField) {
    final mapExpression = refer('Map').property('fromEntries').call([
      refer('items').property('map').call([
        Method(
          (m) => m
            ..requiredParameters.add(Parameter((p) => p..name = 'item'))
            ..lambda = true
            ..body = refer('MapEntry').call([
              refer('item').property(idField),
              refer('item'),
            ]).code,
        ).closure,
      ]),
    ]);
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('map').assign(mapExpression).statement,
        )
        ..statements.add(
          refer('_box').property('putAll').call([refer('map')]).awaited.statement,
        ),
    );
  }

  Block _buildUpdateWithZorphyBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box').property('values').property('firstWhere').call(
                  [
                    Method(
                      (m) => m
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'item'),
                        )
                        ..lambda = true
                        ..body = refer('item')
                            .property(config.idField)
                            .equalTo(refer('params').property('id'))
                            .code,
                    ).closure,
                  ],
                  {
                    'orElse': Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer('notFoundFailure')
                            .call([
                              literalString('$entityName not found in cache'),
                            ])
                            .thrown
                            .code,
                    ).closure,
                  },
                ),
              )
              .statement,
        )
        ..statements.add(
          declareFinal('updated')
              .assign(
                refer('params').property('data').property('applyTo').call([
                  refer('existing'),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([
                refer('updated').property(config.idField),
                refer('updated'),
              ]).awaited.statement,
        )
        ..statements.add(refer('updated').returned.statement),
    );
  }

  Block _buildUpdateWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box').property('values').property('firstWhere').call(
                  [
                    Method(
                      (m) => m
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'item'),
                        )
                        ..lambda = true
                        ..body = refer('item')
                            .property(config.idField)
                            .equalTo(refer('params').property('id'))
                            .code,
                    ).closure,
                  ],
                  {
                    'orElse': Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer('notFoundFailure')
                            .call([
                              literalString('$entityName not found in cache'),
                            ])
                            .thrown
                            .code,
                    ).closure,
                  },
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([
                refer('existing').property(config.idField),
                refer('existing'),
              ]).awaited.statement,
        )
        ..statements.add(refer('existing').returned.statement),
    );
  }

  Block _buildUpdateSingleWithZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box').property('get').call([
                  literalString(entitySnake),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('existing')
              .equalTo(literalNull)
              .conditional(
                literalNull,
                refer('notFoundFailure')
                    .call([
                      literalString('$entityName not found in cache'),
                    ])
                    .thrown,
              )
              .statement,
        )
        ..statements.add(
          declareFinal('updated')
              .assign(
                refer('params').property('data').property('applyTo').call([
                  refer('existing'),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([literalString(entitySnake), refer('updated')])
              .awaited
              .statement,
        )
        ..statements.add(refer('updated').returned.statement),
    );
  }

  Block _buildUpdateSingleWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box').property('get').call([
                  literalString(entitySnake),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('existing')
              .equalTo(literalNull)
              .conditional(
                literalNull,
                refer('notFoundFailure')
                    .call([
                      literalString('$entityName not found in cache'),
                    ])
                    .thrown,
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([literalString(entitySnake), refer('existing')])
              .awaited
              .statement,
        )
        ..statements.add(refer('existing').returned.statement),
    );
  }

  Block _buildDeleteWithListBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box').property('values').property('firstWhere').call(
                  [
                    Method(
                      (m) => m
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'item'),
                        )
                        ..lambda = true
                        ..body = refer('item')
                            .property(config.idField)
                            .equalTo(refer('params').property('id'))
                            .code,
                    ).closure,
                  ],
                  {
                    'orElse': Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer('notFoundFailure')
                            .call([
                              literalString('$entityName not found in cache'),
                            ])
                            .thrown
                            .code,
                    ).closure,
                  },
                ),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('delete')
              .call([refer('existing').property(config.idField)])
              .awaited
              .statement,
        ),
    );
  }

  Block _buildWatchBody() {
    final existingExpression = refer('_box')
        .property('values')
        .property('query')
        .call([refer('params')]);
    final streamExpression = refer('Stream').property('multi').call([
      Method(
        (m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'controller'))
          ..modifier = MethodModifier.async
          ..body = Block(
            (bb) => bb
              ..statements.add(
                refer('controller')
                    .property('add')
                    .call([refer('existing')]).statement,
              )
              ..statements.add(
                refer('controller')
                    .property('addStream')
                    .call([
                      refer('_box').property('watch').call([]).property('map').call([
                        Method(
                          (mm) => mm
                            ..requiredParameters
                                .add(Parameter((p) => p..name = '_'))
                            ..lambda = true
                            ..body = existingExpression.code,
                        ).closure,
                      ]),
                    ]).awaited.statement,
              ),
          ),
      ).closure,
    ]);
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing').assign(existingExpression).statement,
        )
        ..statements.add(
          declareFinal('stream').assign(streamExpression).statement,
        )
        ..statements.add(refer('stream').returned.statement),
    );
  }

  Block _buildWatchListBody() {
    final existingExpression = refer('_box')
        .property('values')
        .property('filter')
        .call([refer('params').property('filter')])
        .property('orderBy')
        .call([refer('params').property('sort')]);
    final streamExpression = refer('Stream').property('multi').call([
      Method(
        (m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'controller'))
          ..modifier = MethodModifier.async
          ..body = Block(
            (bb) => bb
              ..statements.add(
                refer('controller')
                    .property('add')
                    .call([refer('existing')]).statement,
              )
              ..statements.add(
                refer('controller')
                    .property('addStream')
                    .call([
                      refer('_box').property('watch').call([]).property('map').call([
                        Method(
                          (mm) => mm
                            ..requiredParameters
                                .add(Parameter((p) => p..name = '_'))
                            ..lambda = true
                            ..body = existingExpression.code,
                        ).closure,
                      ]),
                    ]).awaited.statement,
              ),
          ),
      ).closure,
    ]);
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing').assign(existingExpression).statement,
        )
        ..statements.add(
          declareFinal('stream').assign(streamExpression).statement,
        )
        ..statements.add(refer('stream').returned.statement),
    );
  }

  Parameter _param(String name, String type) {
    return Parameter(
      (p) => p
        ..name = name
        ..type = refer(type),
    );
  }
}
