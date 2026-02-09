/// GraphQL schema models for introspection result parsing.
library;

/// GraphQL type kinds from the introspection schema.
enum GqlTypeKind {
  scalar,
  object,
  interface_,
  union,
  enum_,
  inputObject,
  list,
  nonNull,
}

/// Represents a GraphQL type reference, which can be nested for NON_NULL/LIST wrappers.
class GqlTypeRef {
  final GqlTypeKind kind;
  final String? name;
  final GqlTypeRef? ofType;

  const GqlTypeRef({required this.kind, this.name, this.ofType});

  factory GqlTypeRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GqlTypeRef(kind: GqlTypeKind.scalar, name: 'Unknown');
    }
    return GqlTypeRef(
      kind: _parseKind(json['kind'] as String?),
      name: json['name'] as String?,
      ofType: json['ofType'] != null
          ? GqlTypeRef.fromJson(json['ofType'] as Map<String, dynamic>)
          : null,
    );
  }

  static GqlTypeKind _parseKind(String? kind) {
    switch (kind) {
      case 'SCALAR':
        return GqlTypeKind.scalar;
      case 'OBJECT':
        return GqlTypeKind.object;
      case 'INTERFACE':
        return GqlTypeKind.interface_;
      case 'UNION':
        return GqlTypeKind.union;
      case 'ENUM':
        return GqlTypeKind.enum_;
      case 'INPUT_OBJECT':
        return GqlTypeKind.inputObject;
      case 'LIST':
        return GqlTypeKind.list;
      case 'NON_NULL':
        return GqlTypeKind.nonNull;
      default:
        return GqlTypeKind.scalar;
    }
  }

  /// Returns the innermost named type, unwrapping NON_NULL and LIST wrappers.
  GqlTypeRef get namedType {
    if (name != null) return this;
    return ofType?.namedType ?? this;
  }

  /// Whether this type is non-null (required).
  bool get isNonNull => kind == GqlTypeKind.nonNull;

  /// Whether this type is a list.
  bool get isList {
    if (kind == GqlTypeKind.list) return true;
    if (kind == GqlTypeKind.nonNull) return ofType?.isList ?? false;
    return false;
  }

  /// Returns the element type if this is a list, otherwise null.
  GqlTypeRef? get listElementType {
    if (kind == GqlTypeKind.list) return ofType;
    if (kind == GqlTypeKind.nonNull) return ofType?.listElementType;
    return null;
  }
}

/// Represents a GraphQL argument.
class GqlArgument {
  final String name;
  final String? description;
  final GqlTypeRef type;
  final dynamic defaultValue;

  const GqlArgument({
    required this.name,
    this.description,
    required this.type,
    this.defaultValue,
  });

  factory GqlArgument.fromJson(Map<String, dynamic> json) {
    return GqlArgument(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: GqlTypeRef.fromJson(json['type'] as Map<String, dynamic>?),
      defaultValue: json['defaultValue'],
    );
  }
}

/// Represents a GraphQL field.
class GqlField {
  final String name;
  final String? description;
  final GqlTypeRef type;
  final List<GqlArgument> args;

  const GqlField({
    required this.name,
    this.description,
    required this.type,
    this.args = const [],
  });

  factory GqlField.fromJson(Map<String, dynamic> json) {
    return GqlField(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: GqlTypeRef.fromJson(json['type'] as Map<String, dynamic>?),
      args:
          (json['args'] as List<dynamic>?)
              ?.map((a) => GqlArgument.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Represents a GraphQL enum value.
class GqlEnumValue {
  final String name;
  final String? description;

  const GqlEnumValue({required this.name, this.description});

  factory GqlEnumValue.fromJson(Map<String, dynamic> json) {
    return GqlEnumValue(
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

/// Represents a GraphQL type definition.
class GqlTypeDef {
  final String name;
  final GqlTypeKind kind;
  final String? description;
  final List<GqlField>? fields;
  final List<GqlField>? inputFields;
  final List<GqlEnumValue>? enumValues;

  const GqlTypeDef({
    required this.name,
    required this.kind,
    this.description,
    this.fields,
    this.inputFields,
    this.enumValues,
  });

  factory GqlTypeDef.fromJson(Map<String, dynamic> json) {
    return GqlTypeDef(
      name: json['name'] as String,
      kind: GqlTypeRef._parseKind(json['kind'] as String?),
      description: json['description'] as String?,
      fields: (json['fields'] as List<dynamic>?)
          ?.map((f) => GqlField.fromJson(f as Map<String, dynamic>))
          .toList(),
      inputFields: (json['inputFields'] as List<dynamic>?)
          ?.map((f) => GqlField.fromJson(f as Map<String, dynamic>))
          .toList(),
      enumValues: (json['enumValues'] as List<dynamic>?)
          ?.map((e) => GqlEnumValue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Whether this is an OBJECT type.
  bool get isObject => kind == GqlTypeKind.object;

  /// Whether this is an ENUM type.
  bool get isEnum => kind == GqlTypeKind.enum_;

  /// Whether this is an INPUT_OBJECT type.
  bool get isInputObject => kind == GqlTypeKind.inputObject;

  /// Whether this is a built-in type (name starts with `__`).
  bool get isBuiltIn => name.startsWith('__');
}

/// Represents a complete GraphQL schema from introspection.
class GqlSchema {
  final String? queryTypeName;
  final String? mutationTypeName;
  final String? subscriptionTypeName;
  final Map<String, GqlTypeDef> types;

  const GqlSchema({
    this.queryTypeName,
    this.mutationTypeName,
    this.subscriptionTypeName,
    required this.types,
  });

  /// Parses the `__schema` structure from an introspection result.
  factory GqlSchema.fromIntrospection(Map<String, dynamic> data) {
    final schema = data['__schema'] as Map<String, dynamic>? ?? data;

    final queryType = schema['queryType'] as Map<String, dynamic>?;
    final mutationType = schema['mutationType'] as Map<String, dynamic>?;
    final subscriptionType =
        schema['subscriptionType'] as Map<String, dynamic>?;

    final typesList = schema['types'] as List<dynamic>? ?? [];
    final typesMap = <String, GqlTypeDef>{};

    for (final typeJson in typesList) {
      final typeDef = GqlTypeDef.fromJson(typeJson as Map<String, dynamic>);
      typesMap[typeDef.name] = typeDef;
    }

    return GqlSchema(
      queryTypeName: queryType?['name'] as String?,
      mutationTypeName: mutationType?['name'] as String?,
      subscriptionTypeName: subscriptionType?['name'] as String?,
      types: typesMap,
    );
  }

  /// Returns all OBJECT types excluding built-ins and root operation types.
  Iterable<GqlTypeDef> get entityTypes {
    final rootTypes = {queryTypeName, mutationTypeName, subscriptionTypeName};
    return types.values.where(
      (t) => t.isObject && !t.isBuiltIn && !rootTypes.contains(t.name),
    );
  }

  /// Returns all ENUM types excluding built-ins.
  Iterable<GqlTypeDef> get enumTypes {
    return types.values.where((t) => t.isEnum && !t.isBuiltIn);
  }
}
