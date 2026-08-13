class EntityUtils {
  /// Extracts entity type references from a field type string, recursing
  /// through generic type arguments.
  ///
  /// Examples:
  ///   `Product`                    -> [Product]
  ///   `List<Product>`              -> [Product]
  ///   `Map<String, Product>`       -> [Product]
  ///   `List<Map<String, Product>>` -> [Product]
  ///   `Set<String>`                -> []
  ///   `List<Map<String, dynamic>>` -> []
  ///   `Iterable<Product>`          -> [Product]
  static List<String> extractEntityTypes(String fieldType) {
    final types = <String>[];
    _collectTypes(fieldType.replaceAll('?', ''), types);
    return types;
  }

  /// Container/collection wrappers — only their type arguments can
  /// reference entities; the wrapper name itself is never an entity.
  static const _containerTypes = {
    'List',
    'Set',
    'Map',
    'Iterable',
    'Future',
    'Stream',
  };

  /// Primitive / framework types that never resolve to an entity. Note this
  /// intentionally does NOT include `Duration`, `Uri`, `BigInt`, `Uint8List`:
  /// zorphy's `FieldNormalizer` does not treat them as primitives, so it
  /// `$`-prefixes them (`$Duration`) and the build fails with `InvalidType`.
  /// They must stay candidates so `EntityTypeValidator` rejects them with a
  /// clear error instead of writing a broken entity (issue #296).
  static const _nonEntityTypes = {
    'String',
    'int',
    'double',
    'bool',
    'DateTime',
    'Object',
    'dynamic',
    'void',
    'Null',
    'num',
    'NoParams',
    'Params',
    'QueryParams',
    'ListQueryParams',
    'UpdateParams',
    'DeleteParams',
    'InitializationParams',
  };

  static void _collectTypes(String type, List<String> out) {
    final trimmed = type.trim();
    if (trimmed.isEmpty) return;

    final genericMatch = RegExp(r'^([^<]+?)(?:<(.+)>)?$').firstMatch(trimmed);
    if (genericMatch == null) return;

    final baseType = genericMatch.group(1)!.trim();
    final generics = genericMatch.group(2);

    if (_containerTypes.contains(baseType)) {
      if (generics != null) {
        for (final arg in _splitGenericArgs(generics)) {
          _collectTypes(arg, out);
        }
      }
      return;
    }

    final isExplicitEntity = baseType.startsWith(r'$');
    final cleanType = isExplicitEntity
        ? baseType.replaceAll(RegExp(r'^\$+'), '')
        : baseType;

    if (cleanType.isNotEmpty &&
        !_nonEntityTypes.contains(cleanType) &&
        cleanType[0].toUpperCase() == cleanType[0]) {
      out.add(cleanType);
    }

    // Recurse into type arguments of non-container generics too, e.g.
    // `SomeWrapper<Product>` references both `SomeWrapper` and `Product`.
    if (generics != null) {
      for (final arg in _splitGenericArgs(generics)) {
        _collectTypes(arg, out);
      }
    }
  }

  /// Splits a generic argument list on top-level commas, respecting nesting
  /// (e.g. `String, List<Product>` -> ['String', 'List<Product>']).
  static List<String> _splitGenericArgs(String inner) {
    final parts = <String>[];
    var depth = 0;
    final current = StringBuffer();
    for (final char in inner.split('')) {
      if (char == '<') {
        depth++;
      } else if (char == '>') {
        depth--;
      }
      if (char == ',' && depth == 0) {
        final part = current.toString().trim();
        if (part.isNotEmpty) parts.add(part);
        current.clear();
        continue;
      }
      current.write(char);
    }
    final last = current.toString().trim();
    if (last.isNotEmpty) parts.add(last);
    return parts;
  }
}
