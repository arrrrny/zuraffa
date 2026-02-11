import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class MockBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  MockBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      config.name,
      outputDir,
    );
    final isPolymorphic = subtypes.isNotEmpty;

    if (!isPolymorphic) {
      files.add(await _generateMockDataFile(config));
    }

    files.addAll(await _generateNestedEntityMockFiles(config));

    if (!config.generateMockDataOnly) {
      files.add(await _generateMockDataSource(config));
    }

    return files;
  }

  Future<List<GeneratedFile>> _generateNestedEntityMockFiles(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final entityName = config.name;
    final entityFields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
    final processedEntities = <String>{entityName};

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      entityName,
      outputDir,
    );

    for (final subtype in subtypes) {
      if (!processedEntities.contains(subtype)) {
        processedEntities.add(subtype);

        final subtypeConfig = GeneratorConfig(
          name: subtype,
          generateMockDataOnly: true,
        );
        files.add(await _generateMockDataFile(subtypeConfig));

        final subtypeFields = EntityAnalyzer.analyzeEntity(subtype, outputDir);
        await _collectAndGenerateNestedEntities(
          subtypeFields,
          files,
          processedEntities,
        );
      }
    }

    await _collectAndGenerateNestedEntities(
      entityFields,
      files,
      processedEntities,
    );

    return files;
  }

  Future<void> _collectAndGenerateNestedEntities(
    Map<String, String> fields,
    List<GeneratedFile> files,
    Set<String> processedEntities,
  ) async {
    for (final entry in fields.entries) {
      final fieldType = entry.value;
      final baseTypes = _extractEntityTypesFromField(fieldType);

      for (final baseType in baseTypes) {
        if (baseType.isNotEmpty &&
            baseType[0] == baseType[0].toUpperCase() &&
            ![
              'String',
              'int',
              'double',
              'bool',
              'DateTime',
              'Object',
              'dynamic',
            ].contains(baseType) &&
            !processedEntities.contains(baseType)) {
          final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
            baseType,
            outputDir,
          );
          if (subtypes.isNotEmpty) {
            processedEntities.add(baseType);

            for (final subtype in subtypes) {
              if (!processedEntities.contains(subtype)) {
                processedEntities.add(subtype);

                final subtypeConfig = GeneratorConfig(
                  name: subtype,
                  generateMockDataOnly: true,
                );
                files.add(await _generateMockDataFile(subtypeConfig));

                final subtypeFields = EntityAnalyzer.analyzeEntity(
                  subtype,
                  outputDir,
                );
                await _collectAndGenerateNestedEntities(
                  subtypeFields,
                  files,
                  processedEntities,
                );
              }
            }
            continue;
          }

          final entityFields = EntityAnalyzer.analyzeEntity(
            baseType,
            outputDir,
          );
          if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
            processedEntities.add(baseType);

            final nestedConfig = GeneratorConfig(
              name: baseType,
              generateMockDataOnly: true,
            );
            files.add(await _generateMockDataFile(nestedConfig));

            await _collectAndGenerateNestedEntities(
              entityFields,
              files,
              processedEntities,
            );
          }
        }
      }
    }
  }

  Future<GeneratedFile> _generateMockDataFile(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);

    final entityFields = EntityAnalyzer.analyzeEntity(entityName, outputDir);

    final mockInstances = _generateMockDataInstances(entityName, entityFields);

    final imports = _collectNestedEntityImports(entityFields);
    final directives = <Directive>[
      Directive.import('../../domain/entities/$entitySnake/$entitySnake.dart'),
      ...imports.map(Directive.import),
    ];

    final sampleMethod = Method(
      (m) => m
        ..name = 'sample$entityName'
        ..type = MethodType.getter
        ..static = true
        ..returns = refer(entityName)
        ..lambda = true
        ..body = refer('${entityCamel}s').property('first').code,
    );

    final sampleListMethod = Method(
      (m) => m
        ..name = 'sampleList'
        ..type = MethodType.getter
        ..static = true
        ..returns = _listOf(entityName)
        ..lambda = true
        ..body = refer('${entityCamel}s').code,
    );

    final emptyListMethod = Method(
      (m) => m
        ..name = 'emptyList'
        ..type = MethodType.getter
        ..static = true
        ..returns = _listOf(entityName)
        ..lambda = true
        ..body = literalConstList([], refer(entityName)).code,
    );

    final largeListMethod = Method(
      (m) => m
        ..name = 'large${entityName}List'
        ..type = MethodType.getter
        ..static = true
        ..returns = _listOf(entityName)
        ..lambda = true
        ..body = refer('List').property('generate').call([
          literalNum(100),
          Method(
            (m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'index'))
              ..lambda = true
              ..body = refer(
                '_create$entityName',
              ).call([refer('index').operatorAdd(literalNum(1000))]).code,
          ).closure,
        ]).code,
    );

    final createMethod = Method(
      (m) => m
        ..name = '_create$entityName'
        ..static = true
        ..returns = refer(entityName)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'seed'
              ..type = refer('int'),
          ),
        )
        ..lambda = true
        ..body = refer(entityName)
            .call(
              const [],
              _generateConstructorCallArgs(entityFields, useSeeds: true),
            )
            .code,
    );

    final dataListField = Field(
      (f) => f
        ..name = '${entityCamel}s'
        ..static = true
        ..modifier = FieldModifier.final$
        ..type = _listOf(entityName)
        ..assignment = literalList(mockInstances).code,
    );

    final clazz = Class(
      (c) => c
        ..name = '${entityName}MockData'
        ..docs.add('Mock data for $entityName')
        ..fields.add(dataListField)
        ..methods.addAll([
          sampleMethod,
          sampleListMethod,
          emptyListMethod,
          largeListMethod,
          createMethod,
        ]),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    final filePath = '$outputDir/data/mock/${entitySnake}_mock_data.dart';
    return FileUtils.writeFile(
      filePath,
      content,
      'mock_data',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateMockDataSource(GeneratorConfig config) async {
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
            ..returns = _futureVoidType()
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
        ..docs.add('Mock data source for $entityName')
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

  List<Expression> _generateMockDataInstances(
    String entityName,
    Map<String, String> fields,
  ) {
    if (fields.isEmpty) {
      return List.generate(3, (_) => refer(entityName).call(const []));
    }

    return List.generate(
      3,
      (i) => refer(
        entityName,
      ).call(const [], _generateConstructorCallArgs(fields, seed: i + 1)),
    );
  }

  Map<String, Expression> _generateConstructorCallArgs(
    Map<String, String> fields, {
    int seed = 1,
    bool useSeeds = false,
  }) {
    final args = <String, Expression>{};

    for (final entry in fields.entries) {
      args[entry.key] = _generateMockValueExpr(
        entry.key,
        entry.value,
        seed,
        useSeeds,
      );
    }

    return args;
  }

  Expression _generateMockValueExpr(
    String fieldName,
    String fieldType,
    int seed,
    bool useSeeds,
  ) {
    final isNullable = fieldType.endsWith('?');
    final baseType = fieldType.replaceAll('?', '');

    if (useSeeds) {
      return _generateSeededValueExpr(fieldName, baseType, isNullable);
    }

    switch (baseType) {
      case 'String':
        return literalString('$fieldName $seed');
      case 'int':
        return literalNum(seed * 10);
      case 'double':
        return literalNum(seed * 10.5);
      case 'bool':
        return literalBool(seed % 2 == 1);
      case 'DateTime':
        return refer(
          'DateTime',
        ).property('now').call([]).property('subtract').call([
          refer(
            'Duration',
          ).constInstance(const [], {'days': literalNum(seed * 30)}),
        ]);
      case 'Object':
        return literalMap({'key$seed': 'value$seed'});
      default:
        if (baseType.startsWith('List<') && baseType.endsWith('>')) {
          final listType = baseType.substring(5, baseType.length - 1);
          return _generateListValueExpr(listType, seed);
        }
        if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
          return _generateMapValueExpr(baseType, seed);
        }

        if (isNullable && seed % 3 == 0) return literalNull;

        if (baseType.isNotEmpty && baseType[0] == baseType[0].toUpperCase()) {
          final cleanType = baseType.startsWith('\$')
              ? baseType.substring(1)
              : baseType;

          final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
            cleanType,
            outputDir,
          );
          if (subtypes.isNotEmpty) {
            final subtype = subtypes[seed % subtypes.length];
            return refer('${subtype}MockData').property('sample$subtype');
          }

          final entityFields = EntityAnalyzer.analyzeEntity(
            cleanType,
            outputDir,
          );
          if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
            return refer('${cleanType}MockData').property('sample$cleanType');
          }
          return refer(baseType).property('values').index(literalNum(seed % 2));
        }

        return literalString('$fieldName $seed');
    }
  }

  Expression _generateListValueExpr(String listType, int seed) {
    final cleanListType = listType.startsWith('\$')
        ? listType.substring(1)
        : listType;
    final itemCount = 2 + (seed % 2);

    if (cleanListType.isNotEmpty &&
        cleanListType[0] == cleanListType[0].toUpperCase() &&
        ![
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          'Object',
          'dynamic',
        ].contains(cleanListType)) {
      final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
        cleanListType,
        outputDir,
      );

      if (subtypes.isNotEmpty) {
        final items = <Expression>[];
        for (int i = 0; i < itemCount; i++) {
          final subtype = subtypes[(seed + i) % subtypes.length];
          items.add(
            refer('${subtype}MockData')
                .property('${StringUtils.pascalToCamel(subtype)}s')
                .index(literalNum(i % 3)),
          );
        }
        return literalList(items);
      }

      final entityFields = EntityAnalyzer.analyzeEntity(
        cleanListType,
        outputDir,
      );
      if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
        final items = <Expression>[];
        for (int i = 1; i <= itemCount; i++) {
          items.add(
            refer('${cleanListType}MockData')
                .property('${StringUtils.pascalToCamel(cleanListType)}s')
                .index(literalNum((seed + i - 1) % 3)),
          );
        }
        return literalList(items);
      } else {
        return literalList(
          List.generate(
            itemCount,
            (_) => refer(
              '${cleanListType}MockData',
            ).property('sample$cleanListType'),
          ),
        );
      }
    }

    return literalList(
      List.generate(
        itemCount,
        (i) =>
            _generateMockValueExpr('item', cleanListType, seed + i + 1, false),
      ),
    );
  }

  Expression _generateMapValueExpr(String mapType, int seed) {
    final innerTypes = mapType.substring(4, mapType.length - 1);
    final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();

    if (typeParts.length != 2) return literalMap(const {});

    final keyType = typeParts[0];
    final valueType = typeParts[1];
    final itemCount = 2 + (seed % 2);
    final entries = <Expression, Expression>{};

    for (int i = 1; i <= itemCount; i++) {
      final key = _generateSimpleValueExpr(keyType, 'key$i', seed + i);
      final value = _generateMockValueExpr(
        'value$i',
        valueType,
        seed + i,
        false,
      );
      entries[key] = value;
    }

    return literalMap(entries);
  }

  Expression _generateSimpleValueExpr(String type, String name, int seed) {
    switch (type) {
      case 'String':
        return literalString(name);
      case 'int':
        return literalNum(seed * 10);
      case 'double':
        return literalNum(seed * 10.5);
      case 'bool':
        return literalBool(seed % 2 == 1);
      default:
        return literalString(name);
    }
  }

  Expression _generateSeededValueExpr(
    String fieldName,
    String baseType,
    bool isNullable,
  ) {
    switch (baseType) {
      case 'String':
        return literalString(
          '$fieldName ',
        ).operatorAdd(refer('seed').property('toString').call([]));
      case 'int':
        return refer('seed').operatorMultiply(literalNum(10));
      case 'double':
        return refer('seed').operatorMultiply(literalNum(10.5));
      case 'bool':
        return refer(
          'seed',
        ).operatorEuclideanModulo(literalNum(2)).equalTo(literalNum(1));
      case 'DateTime':
        return refer(
          'DateTime',
        ).property('now').call([]).property('subtract').call([
          refer('Duration').call(const [], {
            'days': refer('seed').operatorMultiply(literalNum(30)),
          }),
        ]);
      case 'Object':
        return literalMap({
          literalString('key').operatorAdd(
            refer('seed').property('toString').call([]),
          ): literalString(
            'value',
          ).operatorAdd(refer('seed').property('toString').call([])),
        });
      default:
        if (baseType.startsWith('List<') && baseType.endsWith('>')) {
          final listType = baseType.substring(5, baseType.length - 1);
          return _generateSeededListValueExpr(listType);
        }
        if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
          return _generateSeededMapValueExpr(baseType);
        }

        if (baseType.isNotEmpty && baseType[0] == baseType[0].toUpperCase()) {
          final cleanType = baseType.startsWith('\$')
              ? baseType.substring(1)
              : baseType;

          final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
            cleanType,
            outputDir,
          );
          if (subtypes.isNotEmpty) {
            final subtype = subtypes[0];
            return refer('${subtype}MockData').property('sample$subtype');
          }

          final entityFields = EntityAnalyzer.analyzeEntity(
            cleanType,
            outputDir,
          );
          if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
            return refer('${cleanType}MockData').property('sample$cleanType');
          }
          return refer(cleanType)
              .property('values')
              .index(refer('seed').operatorEuclideanModulo(literalNum(2)));
        }
        return literalString(
          '$fieldName ',
        ).operatorAdd(refer('seed').property('toString').call([]));
    }
  }

  Expression _generateSeededListValueExpr(String listType) {
    final cleanListType = listType.startsWith('\$')
        ? listType.substring(1)
        : listType;

    if (cleanListType.isNotEmpty &&
        cleanListType[0] == cleanListType[0].toUpperCase() &&
        ![
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          'Object',
          'dynamic',
        ].contains(cleanListType)) {
      final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
        cleanListType,
        outputDir,
      );

      if (subtypes.isNotEmpty) {
        final items = <Expression>[];
        for (int i = 0; i < 3; i++) {
          final subtype = subtypes[i % subtypes.length];
          items.add(
            refer('${subtype}MockData')
                .property('${StringUtils.pascalToCamel(subtype)}s')
                .index(refer('seed').operatorEuclideanModulo(literalNum(3))),
          );
        }
        return literalList(items);
      }

      final entityFields = EntityAnalyzer.analyzeEntity(
        cleanListType,
        outputDir,
      );
      if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
        return literalList([
          refer('${cleanListType}MockData')
              .property('${StringUtils.pascalToCamel(cleanListType)}s')
              .index(refer('seed').operatorEuclideanModulo(literalNum(3))),
          refer('${cleanListType}MockData')
              .property('${StringUtils.pascalToCamel(cleanListType)}s')
              .index(
                refer('seed')
                    .operatorAdd(literalNum(1))
                    .operatorEuclideanModulo(literalNum(3)),
              ),
        ]);
      } else {
        return literalList([
          refer('${cleanListType}MockData').property('sample$cleanListType'),
          refer('${cleanListType}MockData').property('sample$cleanListType'),
        ]);
      }
    }

    switch (cleanListType) {
      case 'String':
        return literalList([
          literalString(
            'item ',
          ).operatorAdd(refer('seed').property('toString').call([])),
          literalString(
            'item ',
          ).operatorAdd(refer('seed').property('toString').call([])),
        ]);
      case 'int':
        return literalList([
          refer('seed'),
          refer('seed').operatorAdd(literalNum(1)),
        ]);
      case 'double':
        return literalList([
          refer('seed').operatorMultiply(literalNum(1.5)),
          refer('seed').operatorMultiply(literalNum(2.5)),
        ]);
      case 'bool':
        return literalList([literalBool(true), literalBool(false)]);
      default:
        return literalList([
          refer(cleanListType).call(const []),
          refer(cleanListType).call(const []),
        ]);
    }
  }

  Expression _generateSeededMapValueExpr(String mapType) {
    final innerTypes = mapType.substring(4, mapType.length - 1);
    final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();

    if (typeParts.length != 2) return literalMap(const {});

    final keyType = typeParts[0];
    final valueType = typeParts[1];

    final key1 = _generateSeededSimpleValueExpr(keyType, 'key');
    final value1 = _generateSeededValueExpr('value', valueType, false);

    final key2 = keyType == 'String'
        ? literalString(
            'key2 ',
          ).operatorAdd(refer('seed').property('toString').call([]))
        : _generateSeededSimpleValueExpr(keyType, 'key2');
    final value2 = valueType == 'String'
        ? literalString(
            'value2 ',
          ).operatorAdd(refer('seed').property('toString').call([]))
        : _generateSeededValueExpr('value2', valueType, false);

    return literalMap({key1: value1, key2: value2});
  }

  Expression _generateSeededSimpleValueExpr(String type, String name) {
    switch (type) {
      case 'String':
        return literalString(
          '$name ',
        ).operatorAdd(refer('seed').property('toString').call([]));
      case 'int':
        return refer('seed').operatorMultiply(literalNum(10));
      case 'double':
        return refer('seed').operatorMultiply(literalNum(10.5));
      case 'bool':
        return refer(
          'seed',
        ).operatorEuclideanModulo(literalNum(2)).equalTo(literalNum(1));
      default:
        return literalString(
          '$name ',
        ).operatorAdd(refer('seed').property('toString').call([]));
    }
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
                      declareFinal('item')
                          .assign(
                            refer('${entityName}MockData')
                                .property('${entityCamel}s')
                                .property('query')
                                .call([refer('params')]),
                          )
                          .statement,
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
                ..returns = _listOfFuture(entityName)
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
                      const Code(
                        'if (params.limit != null && params.limit! > 0) {',
                      ),
                      refer('items')
                          .assign(
                            refer('items')
                                .property('take')
                                .call([
                                  refer('params').property('limit').nullChecked,
                                ])
                                .property('toList')
                                .call([]),
                          )
                          .statement,
                      const Code('}'),
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
                        literalString('Creating $entityName: \${item.id}'),
                      ]).statement,
                      refer('Future')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      refer('logger').property('info').call([
                        literalString(
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
          final updateParamsType = 'UpdateParams<${config.idType}, $dataType>';

          Expression orElse;
          if (hasListMethods) {
            orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('throw').call([
                  refer(
                    'notFoundFailure',
                  ).call([literalString('$entityName not found')]),
                ]).code,
            ).closure;
          } else {
            orElse = literalNull; // should not be reached if handled properly
          }

          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              literalString('Updating $entityName with id: \${params.id}'),
            ]).statement,
            refer(
              'Future',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (hasListMethods) {
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
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              literalString('Deleting $entityName with id: \${params.id}'),
            ]).statement,
            refer(
              'Future',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (hasListMethods) {
            bodyStatements.addAll([
              declareFinal('exists')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('${entityCamel}s').property('any').call([
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
                    ]),
                  )
                  .statement,
              const Code('if (!exists) {'),
              refer('throw').call([
                refer(
                  'notFoundFailure',
                ).call([literalString('$entityName not found')]),
              ]).statement,
              const Code('}'),
            ]);
          }

          bodyStatements.add(
            refer('logger').property('info').call([
              literalString('Successfully deleted $entityName'),
            ]).statement,
          );

          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..annotations.add(refer('override'))
                ..returns = _futureVoidType()
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
                      ).constInstance(const [], {'seconds': literalNum(1)}),
                      Method(
                        (m) => m
                          ..requiredParameters.add(
                            Parameter((p) => p..name = 'count'),
                          )
                          ..lambda = true
                          ..body = refer('${entityName}MockData')
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
                ..returns = _listOfStream(entityName)
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
                                const Code(
                                  'if (params.limit != null && params.limit! > 0) {',
                                ),
                                refer('items')
                                    .assign(
                                      refer('items')
                                          .property('take')
                                          .call([
                                            refer(
                                              'params',
                                            ).property('limit').nullChecked,
                                          ])
                                          .property('toList')
                                          .call([]),
                                    )
                                    .statement,
                                const Code('}'),
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

  List<String> _extractEntityTypesFromField(String fieldType) {
    final types = <String>[];
    var baseType = fieldType.replaceAll('?', '');

    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      baseType = baseType.substring(5, baseType.length - 1);
    } else if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      final innerTypes = baseType.substring(4, baseType.length - 1);
      final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();
      if (typeParts.length == 2) {
        baseType = typeParts[1];
      } else {
        return types;
      }
    }

    if (baseType.startsWith('\$')) {
      baseType = baseType.substring(1);
    }

    baseType = baseType
        .replaceAll('<', '')
        .replaceAll('>', '')
        .split(',')[0]
        .trim();

    if (baseType.isNotEmpty) {
      types.add(baseType);
    }

    return types;
  }

  bool _isDefaultFields(Map<String, String> fields) {
    final defaultKeys = {
      'id',
      'name',
      'description',
      'price',
      'category',
      'isActive',
      'createdAt',
      'updatedAt',
    };
    return fields.keys.toSet().containsAll(defaultKeys);
  }

  List<String> _collectNestedEntityImports(Map<String, String> fields) {
    final imports = <String>[];
    bool hasEnums = false;

    for (final entry in fields.entries) {
      final fieldType = entry.value;
      var baseType = fieldType.replaceAll('?', '');

      if (baseType.startsWith('List<') && baseType.endsWith('>')) {
        baseType = baseType.substring(5, baseType.length - 1);
      }

      if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
        final innerTypes = baseType.substring(4, baseType.length - 1);
        final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();
        if (typeParts.length == 2) {
          baseType = typeParts[1];
        } else {
          continue;
        }
      }

      if (baseType.startsWith('\$')) {
        baseType = baseType.substring(1);
      }

      if ([
        'String',
        'int',
        'double',
        'bool',
        'DateTime',
        'Object',
      ].contains(baseType)) {
        continue;
      }

      if (baseType.isNotEmpty && baseType[0] == baseType[0].toUpperCase()) {
        final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
          baseType,
          outputDir,
        );
        if (subtypes.isNotEmpty) {
          for (final subtype in subtypes) {
            final subtypeSnake = StringUtils.camelToSnake(subtype);
            imports.add('../mock/${subtypeSnake}_mock_data.dart');
          }
          continue;
        }

        final entityFields = EntityAnalyzer.analyzeEntity(baseType, outputDir);
        if (entityFields.isNotEmpty && !_isDefaultFields(entityFields)) {
          final entitySnake = StringUtils.camelToSnake(baseType);
          imports.add('../mock/${entitySnake}_mock_data.dart');
        } else {
          hasEnums = true;
        }
      }
    }

    if (hasEnums) {
      imports.insert(0, '../../domain/entities/enums/index.dart');
    }

    return imports.toSet().toList();
  }

  Reference _futureVoidType() {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(refer('void')),
    );
  }

  Reference _listOf(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'List'
        ..types.add(refer(entityName)),
    );
  }

  Reference _listOfFuture(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(_listOf(entityName)),
    );
  }

  Reference _listOfStream(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'Stream'
        ..types.add(_listOf(entityName)),
    );
  }
}
