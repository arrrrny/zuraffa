/// Translates GraphQL schema types to Dart entity and enum specifications.
library;

import 'graphql_schema.dart';

/// Specification for a single field in an entity.
class FieldSpec {
  final String name;
  final String dartType;
  final bool isNullable;
  final bool isList;
  final String? description;
  final String? referencedEntity;

  const FieldSpec({
    required this.name,
    required this.dartType,
    required this.isNullable,
    required this.isList,
    this.description,
    this.referencedEntity,
  });

  @override
  String toString() =>
      'FieldSpec(name: $name, dartType: $dartType, isNullable: $isNullable, isList: $isList, referencedEntity: $referencedEntity)';
}

/// Specification for an entity derived from a GraphQL object type.
class EntitySpec {
  final String name;
  final String? description;
  final List<FieldSpec> fields;
  final String idField;
  final String idDartType;

  const EntitySpec({
    required this.name,
    this.description,
    required this.fields,
    required this.idField,
    required this.idDartType,
  });

  @override
  String toString() =>
      'EntitySpec(name: $name, fields: ${fields.length}, idField: $idField, idDartType: $idDartType)';
}

/// Specification for an enum derived from a GraphQL enum type.
class EnumSpec {
  final String name;
  final String? description;
  final List<String> values;

  const EnumSpec({
    required this.name,
    this.description,
    required this.values,
  });

  @override
  String toString() => 'EnumSpec(name: $name, values: $values)';
}

/// Translates GraphQL schema types to Dart-friendly specifications.
class GraphQLSchemaTranslator {
  final GqlSchema schema;
  final Map<String, String> scalarMappings;

  /// Default mappings from GraphQL scalars to Dart types.
  static const Map<String, String> defaultScalarMappings = {
    'String': 'String',
    'ID': 'String',
    'Int': 'int',
    'Float': 'double',
    'Boolean': 'bool',
    'DateTime': 'DateTime',
    'Date': 'DateTime',
    'JSON': 'Map<String, dynamic>',
  };

  GraphQLSchemaTranslator(
    this.schema, {
    Map<String, String>? scalarMappings,
  }) : scalarMappings = {
          ...defaultScalarMappings,
          ...?scalarMappings,
        };

  /// Extracts entity specifications from the schema.
  ///
  /// [include] - If provided, only extract entities with these names.
  /// [exclude] - If provided, exclude entities with these names.
  List<EntitySpec> extractEntitySpecs({
    Set<String>? include,
    Set<String>? exclude,
  }) {
    final specs = <EntitySpec>[];

    for (final typeDef in schema.entityTypes) {
      if (include != null && !include.contains(typeDef.name)) continue;
      if (exclude != null && exclude.contains(typeDef.name)) continue;

      final fields = _extractFields(typeDef);
      final (idField, idDartType) = _inferIdField(fields, typeDef.name);

      specs.add(EntitySpec(
        name: typeDef.name,
        description: typeDef.description,
        fields: fields,
        idField: idField,
        idDartType: idDartType,
      ));
    }

    return specs;
  }

  /// Extracts enum specifications from the schema.
  ///
  /// [include] - If provided, only extract enums with these names.
  /// [exclude] - If provided, exclude enums with these names.
  List<EnumSpec> extractEnumSpecs({
    Set<String>? include,
    Set<String>? exclude,
  }) {
    final specs = <EnumSpec>[];

    for (final typeDef in schema.enumTypes) {
      if (include != null && !include.contains(typeDef.name)) continue;
      if (exclude != null && exclude.contains(typeDef.name)) continue;

      final values =
          typeDef.enumValues?.map((v) => v.name).toList() ?? <String>[];

      specs.add(EnumSpec(
        name: typeDef.name,
        description: typeDef.description,
        values: values,
      ));
    }

    return specs;
  }

  List<FieldSpec> _extractFields(GqlTypeDef typeDef) {
    final gqlFields = typeDef.fields ?? [];
    return gqlFields.map((field) {
      final isNullable = !field.type.isNonNull;
      final isList = field.type.isList;
      final dartType = _toDartType(field.type);
      final referencedEntity = _getReferencedEntity(field.type);

      return FieldSpec(
        name: field.name,
        dartType: dartType,
        isNullable: isNullable,
        isList: isList,
        description: field.description,
        referencedEntity: referencedEntity,
      );
    }).toList();
  }

  String _toDartType(GqlTypeRef typeRef) {
    switch (typeRef.kind) {
      case GqlTypeKind.nonNull:
        return _toDartType(typeRef.ofType!);

      case GqlTypeKind.list:
        final elementType =
            typeRef.ofType != null ? _toDartType(typeRef.ofType!) : 'dynamic';
        return 'List<$elementType>';

      case GqlTypeKind.scalar:
        final name = typeRef.name ?? 'dynamic';
        return scalarMappings[name] ?? 'dynamic';

      case GqlTypeKind.enum_:
        return typeRef.name ?? 'dynamic';

      case GqlTypeKind.object:
      case GqlTypeKind.interface_:
      case GqlTypeKind.union:
      case GqlTypeKind.inputObject:
        return typeRef.name ?? 'dynamic';
    }
  }

  String? _getReferencedEntity(GqlTypeRef typeRef) {
    final namedType = typeRef.namedType;

    if (namedType.kind == GqlTypeKind.object ||
        namedType.kind == GqlTypeKind.interface_) {
      final typeName = namedType.name;
      if (typeName != null && schema.types[typeName]?.isObject == true) {
        final rootTypes = {
          schema.queryTypeName,
          schema.mutationTypeName,
          schema.subscriptionTypeName,
        };
        if (!rootTypes.contains(typeName) && !typeName.startsWith('__')) {
          return typeName;
        }
      }
    }

    return null;
  }

  (String, String) _inferIdField(List<FieldSpec> fields, String entityName) {
    if (fields.isEmpty) {
      return ('id', 'String');
    }

    // Priority 1: field named 'id'
    final idField = fields.where((f) => f.name == 'id').firstOrNull;
    if (idField != null) {
      return ('id', idField.dartType);
    }

    // Priority 2: field named '{entityName}Id' (camelCase)
    final entityIdName = '${_toCamelCase(entityName)}Id';
    final entityIdField =
        fields.where((f) => f.name == entityIdName).firstOrNull;
    if (entityIdField != null) {
      return (entityIdName, entityIdField.dartType);
    }

    // Priority 3: any field ending with 'Id'
    final anyIdField =
        fields.where((f) => f.name.endsWith('Id')).firstOrNull;
    if (anyIdField != null) {
      return (anyIdField.name, anyIdField.dartType);
    }

    // Priority 4: first field
    final firstField = fields.first;
    return (firstField.name, firstField.dartType);
  }

  String _toCamelCase(String pascalCase) {
    if (pascalCase.isEmpty) return pascalCase;
    return pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }
}
