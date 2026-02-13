import 'package:code_builder/code_builder.dart';

import '../../../utils/entity_analyzer.dart';
import '../../../utils/string_utils.dart';
import 'mock_entity_helper.dart';

class MockValueBuilder {
  final String outputDir;
  final MockEntityHelper entityHelper;

  MockValueBuilder({required this.outputDir, MockEntityHelper? entityHelper})
    : entityHelper = entityHelper ?? const MockEntityHelper();

  List<Expression> generateMockDataInstances(
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
      ).call(const [], generateConstructorCallArgs(fields, seed: i + 1)),
    );
  }

  Map<String, Expression> generateConstructorCallArgs(
    Map<String, String> fields, {
    int seed = 1,
    bool useSeeds = false,
  }) {
    final args = <String, Expression>{};

    for (final entry in fields.entries) {
      args[entry.key] = generateMockValueExpr(
        entry.key,
        entry.value,
        seed,
        useSeeds,
      );
    }

    return args;
  }

  Expression generateMockValueExpr(
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

    final primitiveExpr = _primitiveValueExpr(baseType, fieldName, seed);
    if (primitiveExpr != null) {
      return primitiveExpr;
    }

    final collectionExpr = _collectionValueExpr(baseType, seed);
    if (collectionExpr != null) {
      return collectionExpr;
    }

    if (isNullable && seed % 3 == 0) {
      return literalNull;
    }

    final entityExpr = _entityValueExpr(baseType, seed);
    if (entityExpr != null) {
      return entityExpr;
    }

    return literalString('$fieldName $seed');
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
      if (entityFields.isNotEmpty &&
          !entityHelper.isDefaultFields(entityFields)) {
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
            generateMockValueExpr('item', cleanListType, seed + i + 1, false),
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
      final value = generateMockValueExpr(
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
    final primitiveExpr = _seededPrimitiveValueExpr(baseType, fieldName);
    if (primitiveExpr != null) {
      return primitiveExpr;
    }

    final collectionExpr = _seededCollectionValueExpr(baseType);
    if (collectionExpr != null) {
      return collectionExpr;
    }

    final entityExpr = _seededEntityValueExpr(baseType);
    if (entityExpr != null) {
      return entityExpr;
    }

    return literalString(
      '$fieldName ',
    ).operatorAdd(refer('seed').property('toString').call([]));
  }

  Expression _generateSeededListValueExpr(String listType) {
    final cleanListType = listType.startsWith('\$')
        ? listType.substring(1)
        : listType;

    final entityListExpr = _seededEntityListValueExpr(cleanListType);
    if (entityListExpr != null) {
      return entityListExpr;
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

  Expression? _primitiveValueExpr(String baseType, String fieldName, int seed) {
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
        return null;
    }
  }

  Expression? _collectionValueExpr(String baseType, int seed) {
    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      final listType = baseType.substring(5, baseType.length - 1);
      return _generateListValueExpr(listType, seed);
    }
    if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      return _generateMapValueExpr(baseType, seed);
    }
    return null;
  }

  Expression? _entityValueExpr(String baseType, int seed) {
    if (baseType.isEmpty || baseType[0] != baseType[0].toUpperCase()) {
      return null;
    }

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

    final entityFields = EntityAnalyzer.analyzeEntity(cleanType, outputDir);
    if (entityFields.isNotEmpty &&
        !entityHelper.isDefaultFields(entityFields)) {
      return refer('${cleanType}MockData').property('sample$cleanType');
    }

    return refer(baseType).property('values').index(literalNum(seed % 2));
  }

  Expression? _seededPrimitiveValueExpr(String baseType, String fieldName) {
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
        return null;
    }
  }

  Expression? _seededCollectionValueExpr(String baseType) {
    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      final listType = baseType.substring(5, baseType.length - 1);
      return _generateSeededListValueExpr(listType);
    }
    if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      return _generateSeededMapValueExpr(baseType);
    }
    return null;
  }

  Expression? _seededEntityValueExpr(String baseType) {
    if (baseType.isEmpty || baseType[0] != baseType[0].toUpperCase()) {
      return null;
    }

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

    final entityFields = EntityAnalyzer.analyzeEntity(cleanType, outputDir);
    if (entityFields.isNotEmpty &&
        !entityHelper.isDefaultFields(entityFields)) {
      return refer('${cleanType}MockData').property('sample$cleanType');
    }

    return refer(cleanType)
        .property('values')
        .index(refer('seed').operatorEuclideanModulo(literalNum(2)));
  }

  Expression? _seededEntityListValueExpr(String cleanListType) {
    if (cleanListType.isEmpty ||
        cleanListType[0] != cleanListType[0].toUpperCase() ||
        [
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          'Object',
          'dynamic',
        ].contains(cleanListType)) {
      return null;
    }

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

    final entityFields = EntityAnalyzer.analyzeEntity(cleanListType, outputDir);
    if (entityFields.isNotEmpty &&
        !entityHelper.isDefaultFields(entityFields)) {
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
    }

    return literalList([
      refer('${cleanListType}MockData').property('sample$cleanListType'),
      refer('${cleanListType}MockData').property('sample$cleanListType'),
    ]);
  }
}
