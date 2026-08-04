import '../types/graphql_type.dart';

/// Maps GraphQL types to Dart types for code generation.
///
/// Handles custom scalars, enums, and configured type overrides
/// from `.zfa.json`.
class TypeMapper {
  TypeMapper({
    Map<String, String>? customScalars,
    Map<String, String>? typeOverrides,
  }) : _customScalars = customScalars ?? const {},
       _typeOverrides = typeOverrides ?? const {};

  final Map<String, String> _customScalars;
  final Map<String, String> _typeOverrides;

  /// Map a [GraphQLType] to its Dart equivalent.
  ///
  /// - Built-in scalars: `String`, `int`, `double`, `bool`
  /// - Custom scalars: looked up in `_customScalars`, defaults to `String`
  /// - Enums: enum name (e.g. `CurrencyCode`)
  /// - Objects/Inputs: class name (e.g. `Product`)
  /// - Unions: union name (e.g. `AddItemToOrderResult`)
  /// - Lists: `List<T>`
  /// - Non-null: `T` (no `?`)
  String mapType(GraphQLType type) {
    if (type is GraphQLNonNullType) {
      // Non-null context: inner type maps without the nullable marker.
      return _mapNonNull(type.ofType);
    }
    if (type is GraphQLListType) {
      // List elements keep their own nullability (e.g. `[String]` ->
      // `List<String?>`), and the list itself stays non-null unless
      // wrapped in NonNull — GraphQL list nullability is conveyed by the
      // wrapper, so a bare list maps to `List<T>` here.
      return 'List<${mapType(type.ofType)}>';
    }
    // Named types (scalar/enum/object/input/union/interface) are nullable
    // by default.
    return '${_namedBase(type)}?';
  }

  String _mapNonNull(GraphQLType type) {
    if (type is GraphQLNonNullType) return _mapNonNull(type.ofType);
    if (type is GraphQLListType) return 'List<${mapType(type.ofType)}>';
    return _namedBase(type);
  }

  String _namedBase(GraphQLType type) {
    // Type overrides take precedence over built-in mapping.
    final override = _typeOverrides[type.name];
    if (override != null) return override;

    return switch (type) {
      GraphQLScalarType t => _mapScalar(t),
      GraphQLEnumType t => t.name,
      GraphQLObjectType t => t.name,
      GraphQLInputObjectType t => t.name,
      GraphQLUnionType t => t.name,
      GraphQLInterfaceType t => t.name,
      _ => 'dynamic',
    };
  }

  String _mapScalar(GraphQLScalarType scalar) {
    // Check custom scalar mapping
    final custom = _customScalars[scalar.name];
    if (custom != null) return custom;

    // Default built-in scalars
    return switch (scalar.name) {
      'String' || 'ID' => 'String',
      'Int' => 'int',
      'Float' => 'double',
      'Boolean' => 'bool',
      _ => 'String', // Unknown custom scalars default to String
    };
  }

  /// Map a GraphQL field name to a Dart field name (camelCase).
  static String fieldName(String graphQLName) {
    // GraphQL fields are already camelCase typically, but handle edge cases
    return graphQLName;
  }

  /// Map a GraphQL type name to a Dart class name (PascalCase).
  static String className(String graphQLName) => graphQLName;

  /// Map a GraphQL enum value to a Dart enum value (camelCase).
  static String enumValue(String graphQLValue) {
    // Convert SCREAMING_SNAKE_CASE to camelCase
    final parts = graphQLValue
        .toLowerCase()
        .split('_')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first;
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }
}
