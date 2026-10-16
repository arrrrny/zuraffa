import '../../../utils/entity_analyzer.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';

class MockEntityHelper {
  const MockEntityHelper();

  List<String> extractEntityTypesFromField(String fieldType) {
    return EntityUtils.extractEntityTypes(fieldType);
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
    final enumTypes = <String>{};

    for (final entry in fields.entries) {
      final fieldType = entry.value;
      final baseTypes = EntityUtils.extractEntityTypes(fieldType);

      for (final baseType in baseTypes) {
        final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
          baseType,
          outputDir,
        );
        if (subtypes.isNotEmpty) {
          for (final subtype in subtypes) {
            final subtypeSnake = StringUtils.camelToSnake(subtype);
            imports.add('${subtypeSnake}_mock_data.dart');
          }
          continue;
        }

        final entityFields = EntityAnalyzer.analyzeEntity(baseType, outputDir);
        if (EntityAnalyzer.isEnum(baseType, outputDir)) {
          enumTypes.add(baseType);
          final entitySnake = StringUtils.camelToSnake(baseType);
          imports.add('${entitySnake}_mock_data.dart');
          continue;
        }

        if (entityFields.isNotEmpty && !isDefaultFields(entityFields)) {
          final entitySnake = StringUtils.camelToSnake(baseType);
          imports.add('${entitySnake}_mock_data.dart');
        } else if (entityFields.isEmpty &&
            ![
              'String',
              'int',
              'double',
              'bool',
              'DateTime',
              'List',
              'Map',
              'NoParams',
            ].contains(baseType)) {
          if (EntityAnalyzer.isEnum(baseType, outputDir)) {
            enumTypes.add(baseType);
            final entitySnake = StringUtils.camelToSnake(baseType);
            imports.add('${entitySnake}_mock_data.dart');
          }
        }
      }
    }

    // Issue #1735: the mock data body names the enum type directly, so it needs
    // the enum DECLARATION in scope — not a `domain/entities/enums/index.dart`
    // barrel that only exists when the project happens to keep its enums there.
    if (enumTypes.isNotEmpty) {
      final enumImports =
          enumTypes
              .map(
                (type) => EntityAnalyzer.getEntityImportPath(type, outputDir),
              )
              .toList()
            ..sort();
      imports.insertAll(0, enumImports);
    }

    return imports.toSet().toList();
  }
}
