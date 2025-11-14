/// JSON parser that infers primitive types from JSON data
///
/// Supports: String, int, double, bool, DateTime, List<T>, nested objects
/// Philosophy: Primitives only, forever.
class JsonParser {
  /// Parse JSON and return entity schema
  EntitySchema parseJson(Map<String, dynamic> json, {String? entityName}) {
    entityName ??= 'Entity';

    final fields = <FieldSchema>[];
    final nestedEntities = <EntitySchema>[];

    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;

      final fieldType = _inferType(value);

      if (fieldType == '_NestedObject') {
        // Nested object → create separate entity
        final nestedEntityName = _toPascalCase(key);
        final nestedSchema = parseJson(
          value as Map<String, dynamic>,
          entityName: nestedEntityName,
        );
        nestedEntities.add(nestedSchema);

        fields.add(FieldSchema(
          name: key,
          type: nestedEntityName,
          isNullable: false,
          isPrimitive: false,
        ));
      } else if (fieldType.startsWith('List<_NestedObject>')) {
        // Array of objects → create separate entity
        final list = value as List;
        if (list.isEmpty) {
          // Empty array - can't infer type
          fields.add(FieldSchema(
            name: key,
            type: 'List<dynamic>',
            isNullable: false,
            isPrimitive: false,
          ));
        } else {
          final itemEntityName = _singularize(_toPascalCase(key));

          // Parse all items and merge schemas to get accurate type inference
          final itemSchema = _parseListItems(list, itemEntityName);
          nestedEntities.add(itemSchema);

          fields.add(FieldSchema(
            name: key,
            type: 'List<$itemEntityName>',
            isNullable: false,
            isPrimitive: false,
          ));
        }
      } else {
        // Primitive type
        fields.add(FieldSchema(
          name: key,
          type: fieldType,
          isNullable: value == null,
          isPrimitive: true,
        ));
      }
    }

    return EntitySchema(
      name: entityName,
      fields: fields,
      nestedEntities: nestedEntities,
    );
  }

  /// Infer primitive type from JSON value
  String _inferType(dynamic value) {
    if (value == null) {
      return 'dynamic'; // Will be nullable
    }

    if (value is bool) {
      return 'bool';
    }

    if (value is int) {
      return 'int';
    }

    if (value is double) {
      return 'double';
    }

    if (value is num) {
      // Could be int or double - check if it has decimals
      return value == value.toInt() ? 'int' : 'double';
    }

    if (value is String) {
      // Check if it's ISO 8601 DateTime
      if (_isIso8601DateTime(value)) {
        return 'DateTime';
      }
      return 'String';
    }

    if (value is List) {
      if (value.isEmpty) {
        return 'List<dynamic>';
      }

      final firstItemType = _inferType(value[0]);

      if (firstItemType == '_NestedObject') {
        return 'List<_NestedObject>';
      }

      // Get types of all items
      final itemTypes = value.map((item) => _inferType(item)).toSet();

      // If all same type, use that type
      if (itemTypes.length == 1) {
        return 'List<$firstItemType>';
      }

      // Special case: mix of int and double → use double (more general)
      if (itemTypes.contains('int') && itemTypes.contains('double') && itemTypes.length == 2) {
        return 'List<double>';
      }

      // Mixed types
      return 'List<dynamic>';
    }

    if (value is Map<String, dynamic>) {
      return '_NestedObject'; // Marker for nested entity
    }

    return 'dynamic';
  }

  /// Check if string matches ISO 8601 DateTime format
  bool _isIso8601DateTime(String value) {
    // Match: 2025-11-14T12:34:56Z or 2025-11-14T12:34:56.123Z
    final iso8601Pattern = RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$',
    );
    return iso8601Pattern.hasMatch(value);
  }

  /// Convert snake_case or camelCase to PascalCase
  String _toPascalCase(String input) {
    // Handle snake_case
    if (input.contains('_')) {
      return input
          .split('_')
          .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
          .join('');
    }

    // Handle camelCase
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  /// Simple singularization (remove 's' at end)
  String _singularize(String plural) {
    if (plural.endsWith('ies')) {
      return plural.substring(0, plural.length - 3) + 'y';
    }
    if (plural.endsWith('s') && !plural.endsWith('ss')) {
      return plural.substring(0, plural.length - 1);
    }
    return plural;
  }

  /// Parse list items and merge schemas to get accurate type inference
  /// Checks all items, not just the first one
  EntitySchema _parseListItems(List list, String entityName) {
    // Collect field info from ALL items
    final Map<String, Set<String>> fieldTypes = {};
    final Map<String, bool> fieldNullability = {};

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;

      for (final entry in item.entries) {
        final key = entry.key;
        final value = entry.value;

        // Track nullability
        fieldNullability[key] = fieldNullability[key] ?? false;
        if (value == null) {
          fieldNullability[key] = true;
        }

        // Track type
        final type = _inferType(value);
        fieldTypes[key] = fieldTypes[key] ?? <String>{};
        fieldTypes[key]!.add(type);
      }
    }

    // Build fields from merged data
    final fields = <FieldSchema>[];
    final nestedEntities = <EntitySchema>[];

    for (final key in fieldTypes.keys) {
      final types = fieldTypes[key]!;
      final isNullable = fieldNullability[key]!;

      // Determine final type
      String finalType;
      if (types.length == 1) {
        finalType = types.first;
      } else if (types.contains('int') && types.contains('double') && types.length == 2) {
        // Mix of int and double → use double
        finalType = 'double';
      } else {
        // Mixed types
        finalType = 'dynamic';
      }

      // Handle nested objects
      if (finalType == '_NestedObject') {
        final nestedEntityName = _toPascalCase(key);
        // Get first non-null nested object to parse
        final nestedItem = list.firstWhere(
          (item) => item is Map && item[key] is Map,
          orElse: () => null,
        );

        if (nestedItem != null) {
          final nestedSchema = parseJson(
            nestedItem[key] as Map<String, dynamic>,
            entityName: nestedEntityName,
          );
          nestedEntities.add(nestedSchema);

          fields.add(FieldSchema(
            name: key,
            type: nestedEntityName,
            isNullable: isNullable,
            isPrimitive: false,
          ));
        }
      } else {
        fields.add(FieldSchema(
          name: key,
          type: finalType,
          isNullable: isNullable,
          isPrimitive: true,
        ));
      }
    }

    return EntitySchema(
      name: entityName,
      fields: fields,
      nestedEntities: nestedEntities,
    );
  }
}

/// Schema representing a parsed entity
class EntitySchema {
  final String name;
  final List<FieldSchema> fields;
  final List<EntitySchema> nestedEntities;

  EntitySchema({
    required this.name,
    required this.fields,
    required this.nestedEntities,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Entity: $name');
    for (final field in fields) {
      buffer.writeln('  - ${field.name}: ${field.type}${field.isNullable ? '?' : ''}');
    }
    if (nestedEntities.isNotEmpty) {
      buffer.writeln('  Nested:');
      for (final nested in nestedEntities) {
        buffer.writeln('    - ${nested.name}');
      }
    }
    return buffer.toString();
  }
}

/// Schema representing a field in an entity
class FieldSchema {
  final String name;
  final String type;
  final bool isNullable;
  final bool isPrimitive;

  FieldSchema({
    required this.name,
    required this.type,
    required this.isNullable,
    required this.isPrimitive,
  });
}
