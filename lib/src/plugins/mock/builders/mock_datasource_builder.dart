import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import 'mock_type_helper.dart';

class MockDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  MockDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<GeneratedFile> generateMockDataSource(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final filePath =
        '$outputDir/data/datasources/$entitySnake/${entitySnake}_mock_datasource.dart';
    final fileExists = await fileSystem.exists(filePath);

    // Issue #942: the mock datasource imports the entity file AND the
    // framework mock barrel unprefixed. When the entity's name matches a
    // zuraffa core export (an entity named `Credentials` — the framework
    // exports its own `Credentials` params class), every use of the name
    // is an `ambiguous_import` error and the generated tree does not
    // compile. The generator knows the entity's own symbols, so the
    // barrel import hides exactly those symbols and the entity's own
    // definitions win resolution. With no locally-imported entity types
    // the hide list is empty and the import is emitted unchanged.
    final barrelHide = <String>{
      if (config.isEntityBased) ...EntityUtils.barrelHideNames(entityName),
      if (config.isCustomUseCase && config.returnsType != null)
        for (final type in EntityUtils.extractEntityTypes(config.returnsType!))
          ...EntityUtils.barrelHideNames(type),
    }.toList();

    final directives = [
      Directive.import('dart:async'),
      // Canonical zuraffa-native mock marker: detects native mocking for static
      // tooling (e.g. speckit-tdd-setup) without a third-party double library.
      Directive.import('package:zuraffa/mock.dart', hide: barrelHide),
      if (config.isEntityBased)
        Directive.import(
          '../../../domain/entities/$entitySnake/$entitySnake.dart',
        ),
      if (config.isCustomUseCase && config.returnsType != null)
        ...EntityUtils.extractEntityTypes(config.returnsType!).map((type) {
          final snake = StringUtils.camelToSnake(type);
          return Directive.import(
            '../../../domain/entities/$snake/$snake.dart',
          );
        }),
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
                  refer('Future<void>')
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

      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..annotations.add(refer('override'))
            ..returns = typeHelper.futureVoidType()
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Disposing ${entityName}MockDataSource'),
                  ]).statement,
                ),
            ),
        ),
      );
    }

    methods.addAll(_generateMockDataSourceMethods(config));

    if (config.appendToExisting && fileExists) {
      final existing = await fileSystem.read(filePath);
      var updated = existing;

      // Add missing imports
      final entities = <String>{};
      if (config.paramsType != null && config.paramsType != 'NoParams') {
        entities.addAll(EntityUtils.extractEntityTypes(config.paramsType!));
      }
      if (config.returnsType != null && config.returnsType != 'void') {
        entities.addAll(EntityUtils.extractEntityTypes(config.returnsType!));
      }
      final targetEntity = config.isCustomUseCase && config.returnsType != null
          ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
                config.name
          : config.name;
      entities.add('${targetEntity}MockData');

      for (final entityName in entities) {
        final entitySnake = StringUtils.camelToSnake(
          entityName.replaceAll('MockData', ''),
        );
        final isMockData = entityName.endsWith('MockData');
        final importPath = isMockData
            ? '../../mock/${entitySnake}_mock_data.dart'
            : '../../../domain/entities/$entitySnake/$entitySnake.dart';

        if (!updated.contains(importPath)) {
          final importRequest = AppendRequest.import(
            source: updated,
            importPath: importPath,
          );
          updated = appendExecutor.execute(importRequest).source;
        }
      }

      for (final method in methods) {
        final methodSource = specLibrary.emitSpec(method);
        final request = AppendRequest.method(
          source: updated,
          className: '${entityName}MockDataSource',
          memberSource: methodSource,
        );
        final result = config.revert
            ? appendExecutor.undo(request)
            : appendExecutor.execute(request);
        updated = result.source;
      }
      return FileUtils.writeFile(
        filePath,
        updated,
        'mock_datasource',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }

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

    if (config.revert && !config.appendToExisting) {
      return FileUtils.deleteFile(
        filePath,
        'mock_datasource',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'mock_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fileSystem,
    );
  }

  List<Method> _generateMockDataSourceMethods(GeneratorConfig config) {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final methods = <Method>[];

    if (config.isCustomUseCase &&
        (config.paramsType != null || config.returnsType != null)) {
      final methodName = StringUtils.pascalToCamel(config.name);
      final returns = config.returnsType ?? 'void';
      final baseReturns = returns.replaceAll('?', '');
      final isList = baseReturns.startsWith('List<');

      final isStream = config.useCaseType == 'stream';
      final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..annotations.add(refer('override'))
            ..returns = refer(returnType)
            ..modifier = isStream ? null : MethodModifier.async
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
                  if (isStream) ...[
                    refer('Stream')
                        .property('fromFuture')
                        .call([
                          refer('Future<void>').property('delayed').call([
                            refer('_delay'),
                            Method(
                              (mm) => mm
                                ..lambda = true
                                ..body = isList
                                    ? refer(
                                        '${entityName}MockData',
                                      ).property('sampleList').code
                                    : (baseReturns == 'void'
                                          ? refer(
                                              'Future',
                                            ).property('value').call([]).code
                                          : refer('${entityName}MockData')
                                                .property('sample$entityName')
                                                .code),
                            ).closure,
                          ]),
                        ])
                        .returned
                        .statement,
                  ] else ...[
                    refer('Future<void>')
                        .property('delayed')
                        .call([refer('_delay')])
                        .awaited
                        .statement,
                    if (isList) ...[
                      refer(
                        '${entityName}MockData',
                      ).property('sampleList').returned.statement,
                    ] else if (baseReturns == 'void') ...[
                      refer(
                        'Future',
                      ).property('value').call([]).returned.statement,
                    ] else ...[
                      refer(
                        '${entityName}MockData',
                      ).property('sample$entityName').returned.statement,
                    ],
                  ],
                ]),
            ),
        ),
      );
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          final isNoParams = config.idFieldType == 'NoParams';
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
                      refer('Future<void>')
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
                      refer('Future<void>')
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
                      Code(
                        'if (params.offset != null && params.offset! > 0) { items = items.skip(params.offset!).toList(); }',
                      ),
                      Code(
                        'if (params.limit != null && params.limit! > 0) { items = items.take(params.limit!).toList(); }',
                      ),
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
          final isNoParamsCreate = config.idFieldType == 'NoParams';
          // #463: the mock store must be a genuine in-memory implementation —
          // create appends the item to the backing collection so a follow-up
          // get/getList can retrieve it (the submit→get lifecycle).
          final createStatements = <Code>[
            refer('logger').property('info').call([
              isNoParamsCreate
                  ? literalString('Creating $entityName')
                  : literalString('Creating $entityName: \${item.id}'),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
            refer('${entityName}MockData')
                .property('${entityCamel}s')
                .property('add')
                .call([refer('item')])
                .statement,
            refer('logger').property('info').call([
              isNoParamsCreate
                  ? literalString('Successfully created $entityName')
                  : literalString(
                      'Successfully created $entityName: \${item.id}',
                    ),
            ]).statement,
          ];
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
                      ...createStatements,
                      refer('item').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'update':
          final dataType = '${entityName}Patch';
          final updateParamsType =
              'UpdateParams<${config.idFieldType}, $dataType>';
          final isNoParams = config.idFieldType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Updating $entityName')
                  : literalString('Updating $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            // #463: persist singleton updates — apply the patch to the
            // current sample and store the result back at the head of the
            // collection.
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('params').property('data').property('applyTo').call([
                      refer('existing'),
                    ]),
                  )
                  .statement,
              Code('${entityName}MockData.${entityCamel}s[0] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          } else {
            // #463: persist updates — locate by id, apply the patch, and
            // replace the entry in the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
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
              declareFinal('updated')
                  .assign(
                    refer('params').property('data').property('applyTo').call([
                      refer('existing'),
                    ]),
                  )
                  .statement,
              declareFinal('index')
                  .assign(
                    refer('${entityName}MockData')
                        .property('${entityCamel}s')
                        .property('indexOf')
                        .call([refer('existing')]),
                  )
                  .statement,
              Code('${entityName}MockData.${entityCamel}s[index] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('updated').returned.statement,
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

        case 'toggle':
          // #294: the mock datasource must implement `toggle` to match
          // the datasource interface (which now defaults to including
          // toggle in its methods list). Without this case the builder
          // silently dropped toggle, producing a class that failed
          // `implements` with `non_abstract_class_inherits_abstract_member`.
          final toggleFieldEnum = 'Field<$entityName, dynamic>';
          final toggleParamsType =
              'ToggleParams<${config.idFieldType}, $toggleFieldEnum>';
          final isNoParamsToggle = config.idFieldType == 'NoParams';
          final toggleBodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParamsToggle
                  ? literalString('Toggling $entityName')
                  : literalString(
                      'Toggling $entityName: \${params.id} on field \${params.field}',
                    ),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParamsToggle) {
            toggleBodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('existing').property('copyWithField').call([
                      refer('params').property('field'),
                      refer('params').property('value'),
                    ]),
                  )
                  .statement,
              Code('${entityName}MockData.${entityCamel}s[0] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully toggled $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          } else {
            // #463: persist toggles — locate by id, apply the field flip via
            // copyWithField, and replace the entry in the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
            ).closure;
            toggleBodyStatements.addAll([
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
              declareFinal('updated')
                  .assign(
                    refer('existing').property('copyWithField').call([
                      refer('params').property('field'),
                      refer('params').property('value'),
                    ]),
                  )
                  .statement,
              declareFinal('index')
                  .assign(
                    refer('${entityName}MockData')
                        .property('${entityCamel}s')
                        .property('indexOf')
                        .call([refer('existing')]),
                  )
                  .statement,
              Code('${entityName}MockData.${entityCamel}s[index] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully toggled $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(toggleParamsType),
                  ),
                )
                ..body = Block(
                  (b) => b..statements.addAll(toggleBodyStatements),
                ),
            ),
          );
          break;

        case 'delete':
          final deleteParamsType = 'DeleteParams<${config.idFieldType}>';
          final isNoParams = config.idFieldType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Deleting $entityName')
                  : literalString('Deleting $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            bodyStatements.addAll([
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
            ]);
          } else {
            // #463: persist deletes — locate by id (throws notFoundFailure
            // when absent) and remove the entry from the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
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
              refer('${entityName}MockData')
                  .property('${entityCamel}s')
                  .property('remove')
                  .call([refer('existing')])
                  .statement,
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
          final isNoParamsWatch = config.idFieldType == 'NoParams';
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
                                Code(
                                  'if (params.offset != null && params.offset! > 0) { items = items.skip(params.offset!).toList(); }',
                                ),
                                Code(
                                  'if (params.limit != null && params.limit! > 0) { items = items.take(params.limit!).toList(); }',
                                ),
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
