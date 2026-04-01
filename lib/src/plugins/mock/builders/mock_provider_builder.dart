import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/method_extractor.dart';
import '../../../models/parsed_usecase_info.dart';
import 'mock_type_helper.dart';

class MockProviderBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  MockProviderBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create(root: outputDir);

  Future<GeneratedFile> generateMockProvider(GeneratorConfig config) async {
    final serviceName = config.effectiveService;
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    final serviceSnake = config.serviceSnake;

    if (serviceName == null ||
        providerName == null ||
        providerSnake == null ||
        serviceSnake == null) {
      return GeneratedFile(
        path: '',
        content: '',
        action: 'skip',
        type: 'mock_provider',
      );
    }

    final mockProviderName = providerName.replaceAll(
      'Provider',
      'MockProvider',
    );
    final mockProviderSnake = StringUtils.camelToSnake(mockProviderName);
    final fileName = '$mockProviderSnake.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'providers',
      config.effectiveDomain,
      fileName,
    );

    final fileExists = await fileSystem.exists(filePath);

    if (config.revert && !config.appendToExisting) {
      return FileUtils.deleteFile(
        filePath,
        'mock_provider',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');

    final primitives = {
      'String',
      'int',
      'double',
      'bool',
      'void',
      'DateTime',
      'dynamic',
      'Object',
    };
    final isPrimitive =
        primitives.contains(baseReturns) ||
        (isList &&
            primitives.contains(
              baseReturns
                  .substring(5, baseReturns.length - 1)
                  .replaceAll('?', ''),
            ));

    final serviceImport = config.isEntityBased
        ? '../../../domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
        : '../../../domain/services/${serviceSnake}_service.dart';

    final directives = [
      Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(serviceImport),
    ];

    final isStandardEntityMock = config.methods.isNotEmpty;
    final isPrimitiveMock = isPrimitive && !isStandardEntityMock;

    if (!isPrimitiveMock) {
      directives.add(
        Directive.import(
          '../../mock/${StringUtils.camelToSnake(targetEntity)}_mock_data.dart',
        ),
      );
    }

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

    final servicePath = config.isEntityBased
        ? path.join(
            outputDir,
            'domain',
            'services',
            config.effectiveDomain,
            '${serviceSnake}_service.dart',
          )
        : path.join(
            outputDir,
            'domain',
            'services',
            '${serviceSnake}_service.dart',
          );

    final existingMethods = await MethodExtractor.extractMethodsFromInterface(
      servicePath,
      serviceName,
      fileSystem: fileSystem,
    );

    final entityTypes = <String>{};
    if (config.isEntityBased) {
      entityTypes.add(config.name);
    }
    entityTypes.addAll(EntityUtils.extractEntityTypes(returns));
    if (config.paramsType != null && config.paramsType != 'NoParams') {
      entityTypes.addAll(EntityUtils.extractEntityTypes(config.paramsType!));
    }

    for (final info in existingMethods) {
      if (info.paramsType != null && info.paramsType != 'NoParams') {
        entityTypes.addAll(EntityUtils.extractEntityTypes(info.paramsType!));
      }
      if (info.returnsType != null && info.returnsType != 'void') {
        entityTypes.addAll(EntityUtils.extractEntityTypes(info.returnsType!));
      }
    }

    for (final entityName in entityTypes) {
      final entitySnake = StringUtils.camelToSnake(entityName);
      if (EntityAnalyzer.isEnum(
        entityName,
        outputDir,
        fileSystem: fileSystem,
      )) {
        directives.add(
          Directive.import('../../../domain/entities/enums/index.dart'),
        );
      } else {
        final entityPath =
            '../../../domain/entities/$entitySnake/$entitySnake.dart';
        directives.add(Directive.import(entityPath));
        final mockDataImport = '../../mock/${entitySnake}_mock_data.dart';
        directives.add(Directive.import(mockDataImport));
      }
    }

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
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
                    literalString('Initializing $mockProviderName'),
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
                    literalString('$mockProviderName initialized'),
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
            ..returns = refer('Future<void>')
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Disposing $mockProviderName'),
                  ]).statement,
                ),
            ),
        ),
      );
    }

    methods.addAll(_generateMockProviderMethods(config, existingMethods));

    final clazz = Class(
      (c) => c
        ..name = mockProviderName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..docs.add('/// Mock provider for $serviceName')
        ..fields.add(delayField)
        ..constructors.add(constructor)
        ..methods.addAll(methods),
    );

    if (config.appendToExisting && fileExists) {
      final existing = await fileSystem.read(filePath);
      var updated = existing;

      final entities = <String>{};
      if (config.methods.isNotEmpty) {
        entities.add(config.name);
      }
      for (final info in existingMethods) {
        if (info.paramsType != null && info.paramsType != 'NoParams') {
          entities.addAll(EntityUtils.extractEntityTypes(info.paramsType!));
        }
        if (info.returnsType != null && info.returnsType != 'void') {
          entities.addAll(EntityUtils.extractEntityTypes(info.returnsType!));
        }
      }
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
          className: mockProviderName,
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
        'mock_provider',
        force: true,
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
      'mock_provider',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fileSystem,
    );
  }

  List<Method> _generateMockProviderMethods(
    GeneratorConfig config,
    List<ParsedUseCaseInfo> existingMethods,
  ) {
    final methods = <Method>[];

    if (config.methods.isEmpty &&
        existingMethods.isEmpty &&
        config.paramsType == null &&
        config.returnsType == null) {
      return methods;
    }

    if (config.methods.isNotEmpty) {
      for (final method in config.methods) {
        methods.add(_buildEntityMockMethod(config, method));
      }
      return methods;
    }

    if (existingMethods.isNotEmpty) {
      for (final info in existingMethods) {
        final methodName = info.fieldName;
        final returns = info.returnsType ?? 'void';
        final params = info.paramsType ?? 'NoParams';
        final type = info.useCaseType ?? 'usecase';

        final baseReturns = returns.replaceAll('?', '');
        final isList = baseReturns.startsWith('List<');
        final isStream = type == 'stream';
        final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

        final targetEntity =
            config.isCustomUseCase && config.returnsType != null
            ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
                  config.name
            : config.name;

        final primitives = {
          'String',
          'int',
          'double',
          'bool',
          'void',
          'DateTime',
          'dynamic',
          'Object',
        };
        final isPrimitive =
            primitives.contains(baseReturns) ||
            (isList &&
                primitives.contains(
                  baseReturns
                      .substring(5, baseReturns.length - 1)
                      .replaceAll('?', ''),
                ));

        final mockDataClass = '${targetEntity}MockData';
        final sampleProperty = 'sample$targetEntity';

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
                    ..type = refer(params),
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
                            refer('Future').property('delayed').call([
                              refer('_delay'),
                              Method(
                                (mm) => mm
                                  ..lambda = true
                                  ..body = isPrimitive
                                      ? (isList
                                            ? literalList([]).code
                                            : (baseReturns == 'void'
                                                  ? literalNull.code
                                                  : _primitiveValue(
                                                      baseReturns,
                                                    ).code))
                                      : (isList
                                            ? refer(
                                                mockDataClass,
                                              ).property('sampleList').code
                                            : refer(
                                                mockDataClass,
                                              ).property(sampleProperty).code),
                              ).closure,
                            ]),
                          ])
                          .returned
                          .statement,
                    ] else ...[
                      refer('Future')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      if (isPrimitive) ...[
                        if (isList)
                          literalList([]).returned.statement
                        else if (baseReturns == 'void')
                          refer(
                            'Future',
                          ).property('value').call([]).returned.statement
                        else
                          _primitiveValue(baseReturns).returned.statement,
                      ] else ...[
                        if (isList)
                          refer(
                            mockDataClass,
                          ).property('sampleList').returned.statement
                        else
                          refer(
                            mockDataClass,
                          ).property(sampleProperty).returned.statement,
                      ],
                    ],
                  ]),
              ),
          ),
        );
      }
      return methods;
    }

    final methodName = config.getServiceMethodName();
    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    final primitives = {
      'String',
      'int',
      'double',
      'bool',
      'void',
      'DateTime',
      'dynamic',
      'Object',
    };
    final isPrimitive =
        primitives.contains(baseReturns) ||
        (isList &&
            primitives.contains(
              baseReturns
                  .substring(5, baseReturns.length - 1)
                  .replaceAll('?', ''),
            ));

    final mockDataClass = '${targetEntity}MockData';
    final sampleProperty = 'sample$targetEntity';

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';
    final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

    methods.add(
      Method(
        (m) => m
          ..name = methodName
          ..annotations.add(refer('override'))
          ..returns = refer(returnType)
          ..modifier = isStream || isSync ? null : MethodModifier.async
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
                        refer('Future').property('delayed').call([
                          refer('_delay'),
                          Method(
                            (mm) => mm
                              ..lambda = true
                              ..body = isPrimitive
                                  ? (isList
                                        ? literalList([]).code
                                        : (baseReturns == 'void'
                                              ? literalNull.code
                                              : _primitiveValue(
                                                  baseReturns,
                                                ).code))
                                  : (isList
                                        ? refer(
                                            mockDataClass,
                                          ).property('sampleList').code
                                        : refer(
                                            mockDataClass,
                                          ).property(sampleProperty).code),
                          ).closure,
                        ]),
                      ])
                      .returned
                      .statement,
                ] else ...[
                  refer('Future')
                      .property('delayed')
                      .call([refer('_delay')])
                      .awaited
                      .statement,
                  if (isPrimitive) ...[
                    if (isList)
                      literalList([]).returned.statement
                    else if (baseReturns == 'void')
                      literalNull.returned.statement
                    else
                      _primitiveValue(baseReturns).returned.statement,
                  ] else if (isList) ...[
                    refer(
                      mockDataClass,
                    ).property('sampleList').returned.statement,
                  ] else ...[
                    refer(
                      mockDataClass,
                    ).property(sampleProperty).returned.statement,
                  ],
                ],
              ]),
          ),
      ),
    );

    return methods;
  }

  Method _buildEntityMockMethod(GeneratorConfig config, String method) {
    final entityName = config.name;
    final mockDataClass = '${entityName}MockData';
    final sampleProperty = 'sample$entityName';

    String name = method;
    Reference returnType;
    List<Parameter> parameters = [];
    Block body;

    switch (method) {
      case 'get':
        name = 'get';
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('get called with params: \$params'),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
              refer(mockDataClass).property(sampleProperty).returned.statement,
            ]),
        );
        break;
      case 'getList':
      case 'list':
        name = 'getList';
        returnType = refer('Future<List<$entityName>>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('getList called with params: \$params'),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
              refer(mockDataClass).property('sampleList').returned.statement,
            ]),
        );
        break;
      case 'create':
        name = 'create';
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'item'
              ..type = refer(entityName),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('create called with item: \$item'),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
              refer('item').returned.statement,
            ]),
        );
        break;
      case 'update':
        name = 'update';
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(
                'UpdateParams<${config.idFieldType}, ${entityName}Patch>',
              ),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('update called with params: \$params'),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
              refer(mockDataClass).property(sampleProperty).returned.statement,
            ]),
        );
        break;
      case 'delete':
        name = 'delete';
        returnType = refer('Future<void>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('DeleteParams<${config.idFieldType}>'),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('delete called with params: \$params'),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
            ]),
        );
        break;
      case 'watch':
        name = 'watch';
        returnType = refer('Stream<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('watch called with params: \$params'),
              ]).statement,
              refer('Stream')
                  .property('fromFuture')
                  .call([
                    refer('Future').property('delayed').call([
                      refer('_delay'),
                      Method(
                        (mm) => mm
                          ..lambda = true
                          ..body = refer(
                            mockDataClass,
                          ).property(sampleProperty).code,
                      ).closure,
                    ]),
                  ])
                  .returned
                  .statement,
            ]),
        );
        break;
      case 'watchList':
        name = 'watchList';
        returnType = refer('Stream<List<$entityName>>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString('watchList called with params: \$params'),
              ]).statement,
              refer('Stream')
                  .property('fromFuture')
                  .call([
                    refer('Future').property('delayed').call([
                      refer('_delay'),
                      Method(
                        (mm) => mm
                          ..lambda = true
                          ..body = refer(
                            mockDataClass,
                          ).property('sampleList').code,
                      ).closure,
                    ]),
                  ])
                  .returned
                  .statement,
            ]),
        );
        break;
      default:
        throw ArgumentError('Unknown entity method: $method');
    }

    return Method(
      (m) => m
        ..name = name
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = method.startsWith('watch') ? null : MethodModifier.async
        ..requiredParameters.addAll(parameters)
        ..body = body,
    );
  }

  Expression _primitiveValue(String type) {
    switch (type) {
      case 'String':
        return literalString('mock_value');
      case 'int':
        return literalNum(1);
      case 'double':
        return literalNum(1.0);
      case 'bool':
        return literalBool(true);
      case 'DateTime':
        return refer('DateTime').property('now').call([]);
      default:
        return literalNull;
    }
  }
}
