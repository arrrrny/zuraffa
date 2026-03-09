import 'dart:io';
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import 'mock_type_helper.dart';

class MockDataSourceBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;
  final AppendExecutor appendExecutor;

  MockDataSourceBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
    AppendExecutor? appendExecutor,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generateMockDataSource(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);

    final directives = [
      Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      if (config.repo == null)
        Directive.import(
          '../../../domain/entities/$entitySnake/$entitySnake.dart',
        ),
      if (config.isCustomUseCase && config.returnsType != null)
        ...EntityUtils.extractEntityTypes(config.returnsType!).map(
          (type) {
            final snake = StringUtils.camelToSnake(type);
            return Directive.import(
              '../../../domain/entities/$snake/$snake.dart',
            );
          },
        ),
      Directive.import('../../mock/${entitySnake}_mock_data.dart'),
      Directive.import('${entitySnake}_datasource.dart'),
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

    final filePath =
        '$outputDir/data/datasources/$entitySnake/${entitySnake}_mock_datasource.dart';

    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      var updated = existing;
      for (final method in methods) {
        final methodSource = specLibrary.emitSpec(method);
        final result = appendExecutor.execute(
          AppendRequest.method(
            source: updated,
            className: '${entityName}MockDataSource',
            memberSource: methodSource,
          ),
        );
        updated = result.source;
      }
      return FileUtils.writeFile(
        filePath,
        updated,
        'mock_datasource',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        revert: config.revert,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'mock_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      revert: config.revert,
    );
  }

  List<Method> _generateMockDataSourceMethods(GeneratorConfig config) {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final methods = <Method>[];
    final hasListMethods = config.methods.any(
      (m) => m == 'getList' || m == 'watchList',
    );

    // If it's a custom usecase, generate a method for it
    if (config.isCustomUseCase) {
      final methodName = StringUtils.pascalToCamel(config.name);
      final returns = config.returnsType ?? 'void';
      final isNullable = returns.endsWith('?');
      final baseReturns = returns.replaceAll('?', '');
      final isList = baseReturns.startsWith('List<');
      final listEntity =
          isList ? baseReturns.substring(5, baseReturns.length - 1) : '';

      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$returns>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(config.paramsType ?? 'NoParams'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.addAll([
                  refer('logger').property('info').call([
                    literalString('$methodName called with params: \$params'),
                  ]).statement,
                  refer('Future')
                      .property('delayed')
                      .call([refer('_delay')])
                      .awaited
                      .statement,
                  if (isList) ...[
                    refer('${entityName}MockData')
                        .property('sampleList')
                        .returned
                        .statement,
                  ] else if (baseReturns == 'void') ...[
                    refer('Future').property('value').call([]).returned.statement,
                  ] else ...[
                    refer('${entityName}MockData')
                        .property('sample$entityName')
                        .returned
                        .statement,
                  ],
                ]),
            ),
        ),
      );
    }

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
