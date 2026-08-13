class EntityUtils {
  /// Known Dart built-in and framework types that don't require entity/enum
  /// resolution or imports beyond dart:core/dart:typed_data.
  static const Set<String> knownTypes = {
    'String',
    'int',
    'double',
    'bool',
    'DateTime',
    'Duration',
    'Uri',
    'BigInt',
    'Uint8List',
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
  };

  /// Extracts entity types from a field type string (e.g. List Product -> [Product])
  /// Recursively unwraps generic type arguments (List<T>, Map<K,V>, Set<T>, nested).
  static List<String> extractEntityTypes(String fieldType) {
    final types = <String>[];
    _extractEntityTypesRecursive(fieldType, types);
    return types;
  }

  static void _extractEntityTypesRecursive(String fieldType, List<String> accumulator) {
    var baseType = fieldType.trim().replaceAll('?', '');

    // Strip leading $ (Zorphy entity prefix)
    if (baseType.startsWith('\$')) {
      baseType = baseType.substring(1);
    }

    // Recursively unwrap generic wrappers: List<T>, Set<T>, Map<K,V>
    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      final inner = baseType.substring(5, baseType.length - 1);
      _extractEntityTypesRecursive(inner, accumulator);
      return;
    } else if (baseType.startsWith('Set<') && baseType.endsWith('>')) {
      final inner = baseType.substring(4, baseType.length - 1);
      _extractEntityTypesRecursive(inner, accumulator);
      return;
    } else if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      final inner = baseType.substring(4, baseType.length - 1);
      // For Map<K,V>, parse both K and V recursively
      final typeParts = _splitTopLevelComma(inner);
      for (final part in typeParts) {
        _extractEntityTypesRecursive(part, accumulator);
      }
      return;
    }

    // At this point, baseType is not a generic wrapper — check if it's an entity type
    baseType = baseType.trim();
    if (baseType.isNotEmpty &&
        !knownTypes.contains(baseType) &&
        baseType[0].toUpperCase() == baseType[0]) {
      accumulator.add(baseType);
    }
  }

  /// Splits a comma-separated type list at the top level (ignoring commas inside <>).
  /// E.g. "String, List<Product>" -> ["String", "List<Product>"]
  static List<String> _splitTopLevelComma(String input) {
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (final char in input.split('')) {
      if (char == '<') {
        depth++;
        current.write(char);
      } else if (char == '>') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        if (current.toString().trim().isNotEmpty) {
          parts.add(current.toString().trim());
        }
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.toString().trim().isNotEmpty) {
      parts.add(current.toString().trim());
    }
    return parts;
  }
}
