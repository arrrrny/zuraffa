import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import 'mock_type_helper.dart';

class MockDataSourceBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;

  MockDataSourceBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper();

  Future<GeneratedFile> generateMockDataSource(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;

    final directives = [
      Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('../../mock/${entitySnake}_mock_data.dart'),
      Directive.import('${entitySnake}_data_source.dart'),
    ];

    final delayField = Field(
      (f) => f
        ..name = '_delay'
        ..modifier = FieldModifier.final$
        ..type = refer('Duration'),
    );

    final constructor = Constructor(
      (c) => c
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'delay'
              ..type = refer('Duration?'),
          ),
        )
        ..initializers.add(
          refer('_delay')
              .assign(
                refer('delay').ifNullThen(
                  refer(
                    'Duration',
                  ).constInstance(const [], {'milliseconds': literalNum(100)}),
                ),
              )
              .code,
        ),
    );

    final methods = <Method>[];

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(refer('override'))
            ..returns = typeHelper.futureVoidType()
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.addAll([
                  refer('logger').property('info').call([
                    literalString('Initializing ${entityName}MockDataSource'),
                  ]).statement,
                  refer('Future')
                      .property('delayed')
                      .call([
                        refer(
                          'Duration',
                        ).constInstance(const [], {'seconds': literalNum(1)}),
                      ])
                      .awaited
                      .statement,
                  refer('logger').property('info').call([
                    literalString('${entityName}MockDataSource initialized'),
                  ]).statement,
                ]),
            ),
        ),
      );

      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<bool>')
            ..lambda = true
            ..body = refer(
              'Stream',
            ).property('value').call([literalBool(true)]).code,
        ),
      );
    }

    methods.addAll(_generateMockDataSourceMethods(config));

    final clazz = Class(
      (c) => c
        ..name = '${entityName}MockDataSource'
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..docs.add('/// Mock data source for $entityName')
        ..fields.add(delayField)
        ..constructors.add(constructor)
        ..methods.addAll(methods),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    final filePath =
        '$outputDir/data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart';
    return FileUtils.writeFile(
      filePath,
      content,
      'mock_data_source',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  List<Method> _generateMockDataSourceMethods(GeneratorConfig config) {
    final entityName = config.name;
    final entityCamel = config.nameCamel;
    final methods = <Method>[];
    final hasListMethods = config.methods.any(
      (m) => m == 'getList' || m == 'watchList',
    );

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          final isNoParams = config.idType == 'NoParams';
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        literalString(
                          'Getting $entityName with params: \$params',
                        ),
                      ]).statement,
                      refer('Future')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      if (isNoParams) ...[
                        declareFinal('item')
                            .assign(
                              refer(
                                '${entityName}MockData',
                              ).property('sample$entityName'),
                            )
                            .statement,
                      ] else ...[
                        declareFinal('item')
                            .assign(
                              refer('${entityName}MockData')
                                  .property('${entityCamel}s')
                                  .property('query')
                                  .call([refer('params')]),
                            )
                            .statement,
                      ],
                      refer('logger').property('info').call([
                        literalString('Successfully retrieved $entityName'),
                      ]).statement,
                      refer('item').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.listOfFuture(entityName)
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        literalString(
                          'Getting $entityName list with params: \$params',
                        ),
                      ]).statement,
                      refer('Future')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      declareVar('items')
                          .assign(
                            refer(
                              '${entityName}MockData',
                            ).property('${entityCamel}s'),
                          )
                          .statement,
                      refer('params')
                          .property('limit')
                          .notEqualTo(literalNull)
                          .and(
                            refer('params')
                                .property('limit')
                                .nullChecked
                                .greaterThan(literalNum(0)),
                          )
                          .conditional(
                            literalNull,
                            refer('items').assign(
                              refer('items')
                                  .property('take')
                                  .call([
                                    refer(
                                      'params',
                                    ).property('limit').nullChecked,
                                  ])
                                  .property('toList')
                                  .call([]),
                            ),
                          )
                          .statement,
                      refer('logger').property('info').call([
                        literalString(
                          'Successfully retrieved \${items.length} ${entityName}s',
                        ),
                      ]).statement,
                      refer('items').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'create':
          final isNoParamsCreate = config.idType == 'NoParams';
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'item'
                      ..type = refer(entityName),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        isNoParamsCreate
                            ? literalString('Creating $entityName')
                            : literalString(
                                'Creating $entityName: \${item.id}',
                              ),
                      ]).statement,
                      refer('Future')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      refer('logger').property('info').call([
                        isNoParamsCreate
                            ? literalString('Successfully created $entityName')
                            : literalString(
                                'Successfully created $entityName: \${item.id}',
                              ),
                      ]).statement,
                      refer('item').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'update':
          final dataType = config.useZorphy
              ? '${entityName}Patch'
              : 'Map<String, dynamic>';
          final updateParamsType = config.useZorphy
              ? 'UpdateParams<${config.idType}, $dataType>'
              : dataType;
          final hasList = config.methods.contains('getList');
          final hasWatch = config.methods.contains('watch');
          final isNoParams = config.idType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Updating $entityName')
                  : literalString('Updating $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('existing').returned.statement,
            ]);
          } else if (hasList || hasWatch) {
            final orElse = Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer('notFoundFailure').call([
                  literalString('$entityName not found in mock data'),
                ]).code,
            ).closure;
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer('${entityName}MockData')
                        .property('${entityCamel}s')
                        .property('firstWhere')
                        .call(
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
                          {'orElse': orElse},
                        ),
                  )
                  .statement,
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('existing').returned.statement,
            ]);
          } else {
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('existing').returned.statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(updateParamsType),
                  ),
                )
                ..body = Block((b) => b..statements.addAll(bodyStatements)),
            ),
          );
          break;

        case 'delete':
          final deleteParamsType = 'DeleteParams<${config.idType}>';
          final isNoParams = config.idType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Deleting $entityName')
                  : literalString('Deleting $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            bodyStatements.addAll([
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
            ]);
          } else if (hasListMethods) {
            final orElse = Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer('notFoundFailure').call([
                  literalString('$entityName not found in mock data'),
                ]).code,
            ).closure;
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer('${entityName}MockData')
                        .property('${entityCamel}s')
                        .property('firstWhere')
                        .call(
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
                          {'orElse': orElse},
                        ),
                  )
                  .statement,
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
              refer('existing').returned.statement,
            ]);
          } else {
            bodyStatements.addAll([
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.futureVoidType()
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(deleteParamsType),
                  ),
                )
                ..body = Block((b) => b..statements.addAll(bodyStatements)),
            ),
          );
          break;

        case 'watch':
          final isNoParamsWatch = config.idType == 'NoParams';
          methods.add(
            Method(
              (m) => m
                ..name = 'watch'
                ..annotations.add(refer('override'))
                ..returns = refer('Stream<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                      Method(
                        (m) => m
                          ..requiredParameters.add(
                            Parameter((p) => p..name = 'count'),
                          )
                          ..lambda = true
                          ..body = isNoParamsWatch
                              ? refer(
                                  '${entityName}MockData',
                                ).property('sample$entityName').code
                              : refer('${entityName}MockData')
                                    .property('${entityCamel}s')
                                    .property('query')
                                    .call([refer('params')])
                                    .code,
                      ).closure,
                    ])
                    .property('take')
                    .call([literalNum(10)])
                    .returned
                    .statement,
            ),
          );
          break;

        case 'watchList':
          methods.add(
            Method(
              (m) => m
                ..name = 'watchList'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.listOfStream(entityName)
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                      Method(
                        (m) => m
                          ..requiredParameters.add(
                            Parameter((p) => p..name = 'count'),
                          )
                          ..body = Block(
                            (b) => b
                              ..statements.addAll([
                                declareVar('items')
                                    .assign(
                                      refer(
                                        '${entityName}MockData',
                                      ).property('${entityCamel}s'),
                                    )
                                    .statement,
                                refer('params')
                                    .property('limit')
                                    .notEqualTo(literalNull)
                                    .and(
                                      refer('params')
                                          .property('limit')
                                          .nullChecked
                                          .greaterThan(literalNum(0)),
                                    )
                                    .conditional(
                                      literalNull,
                                      refer('items').assign(
                                        refer('items')
                                            .property('take')
                                            .call([
                                              refer(
                                                'params',
                                              ).property('limit').nullChecked,
                                            ])
                                            .property('toList')
                                            .call([]),
                                      ),
                                    )
                                    .statement,
                                refer('items').returned.statement,
                              ]),
                          ),
                      ).closure,
                    ])
                    .property('take')
                    .call([literalNum(5)])
                    .returned
                    .statement,
            ),
          );
          break;
      }
    }

    return methods;
  }
}
