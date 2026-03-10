class EntityUtils {
  /// Extracts entity types from a field type string (e.g. List Product -> [Product])
  static List<String> extractEntityTypes(String fieldType) {
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

    if (baseType.isNotEmpty &&
        ![
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          'Object',
          'dynamic',
          'void',
          'NoParams',
          'Params',
          'QueryParams',
          'ListQueryParams',
          'UpdateParams',
          'DeleteParams',
          'InitializationParams',
        ].contains(baseType) &&
        baseType[0].toUpperCase() == baseType[0]) {
      types.add(baseType);
    }

    return types;
  }
}
