import '../../../utils/entity_analyzer.dart';
import '../../../utils/string_utils.dart';

class MockEntityHelper {
  const MockEntityHelper();

  List<String> extractEntityTypesFromField(String fieldType) {
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

  bool isDefaultFields(Map<String, String> fields) {
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

  List<String> collectNestedEntityImports(
    Map<String, String> fields,
    String outputDir,
  ) {
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
        if (entityFields.isNotEmpty && !isDefaultFields(entityFields)) {
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
}
