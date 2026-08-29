import '../graphql_schema.dart' show GqlTypeKind, GqlTypeRef;
import '../types/graphql_type.dart';
import 'dart_type_namer.dart';

/// Maps GraphQL types to Dart types for code generation.
///
/// Handles custom scalars, enums, and configured type overrides
/// from `.zfa.json`.
///
/// Spec 037 additions:
/// - `DateTime` built-in scalar → `DateTime` (FR-005)
/// - `.zfa.json` `graphql.scalarMap` wiring via [fromZfaConfig] (FR-006)
/// - [mapTypeRef] for raw introspection type references (diff-side)
/// - [unionRepresentation] / [interfaceRepresentation] Dart renderings
///   (FR-008)
class TypeMapper {
  TypeMapper({
    Map<String, String>? customScalars,
    Map<String, String>? typeOverrides,
  }) : _customScalars = customScalars ?? const {},
       _typeOverrides = typeOverrides ?? const {};

  /// Builds a mapper from a parsed `.zfa.json` document, reading
  /// `graphql.scalarMap` (GraphQL scalar name → Dart type name).
  ///
  /// Malformed entries throw [FormatException] with a clear message —
  /// never a silent fallback (spec 037 edge case).
  factory TypeMapper.fromZfaConfig(Map<String, dynamic> zfaJson) {
    final graphql = zfaJson['graphql'];
    if (graphql == null) return TypeMapper();
    if (graphql is! Map) {
      throw const FormatException(
        'The .zfa.json "graphql" section must be a JSON object.',
      );
    }
    final scalarMap = graphql['scalarMap'];
    if (scalarMap == null) return TypeMapper();
    if (scalarMap is! Map) {
      throw const FormatException(
        'graphql.scalarMap must be a JSON object mapping GraphQL scalar '
        'names to Dart type names.',
      );
    }
    final customScalars = <String, String>{};
    for (final entry in scalarMap.entries) {
      if (entry.value is! String) {
        throw FormatException(
          'graphql.scalarMap["${entry.key}"] must be a string Dart type '
          'name, got: ${entry.value}.',
        );
      }
      customScalars[entry.key.toString()] = entry.value as String;
    }
    return TypeMapper(customScalars: customScalars);
  }

  final Map<String, String> _customScalars;
  final Map<String, String> _typeOverrides;

  /// Map a [GraphQLType] to its Dart equivalent.
  ///
  /// - Built-in scalars: `String`, `int`, `double`, `bool`, `DateTime`
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

  /// Maps a raw introspection [GqlTypeRef] (from `GqlSchema`) to a Dart
  /// type string, following the same conventions as [mapType]. Used by the
  /// diff/codegen paths that work on the introspection model directly.
  String mapTypeRef(GqlTypeRef ref) {
    switch (ref.kind) {
      case GqlTypeKind.nonNull:
        final inner = ref.ofType!;
        if (inner.kind == GqlTypeKind.list) {
          return 'List<${mapTypeRef(inner.ofType!)}>';
        }
        return _namedBaseRef(inner);
      case GqlTypeKind.list:
        return 'List<${mapTypeRef(ref.ofType!)}>';
      default:
        return '${_namedBaseRef(ref)}?';
    }
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

  String _namedBaseRef(GqlTypeRef ref) {
    if (ref.kind == GqlTypeKind.scalar) {
      final override = _typeOverrides[ref.name];
      if (override != null) return override;
      return _mapScalarName(ref.name ?? '');
    }
    final override = _typeOverrides[ref.name];
    if (override != null) return override;
    return ref.name ?? 'dynamic';
  }

  String _mapScalar(GraphQLScalarType scalar) => _mapScalarName(scalar.name);

  String _mapScalarName(String name) {
    // Check custom scalar mapping (from .zfa.json graphql.scalarMap).
    final custom = _customScalars[name];
    if (custom != null) return custom;

    // Default built-in scalars (FR-005 — DateTime included).
    return switch (name) {
      'String' || 'ID' => 'String',
      'Int' => 'int',
      'Float' => 'double',
      'Boolean' => 'bool',
      'DateTime' => 'DateTime',
      _ => 'String', // Unknown custom scalars default to String
    };
  }

  /// Renders a Dart `sealed class` hierarchy for a GraphQL union type:
  /// every member type gets a typed variant class so all members remain
  /// accessible with their concrete types (FR-008).
  String unionRepresentation(GraphQLUnionType type) {
    final unionName = DartTypeNamer.className(type.name);
    final buffer = StringBuffer();
    buffer.writeln(
      '/// Dart representation of the GraphQL union `${type.name}`.',
    );
    buffer.writeln('sealed class $unionName {');
    buffer.writeln('  const $unionName();');
    buffer.writeln('}');
    for (final member in type.possibleTypes) {
      final memberClass = DartTypeNamer.className(member);
      final variantClass = '$unionName$memberClass';
      final fieldName = DartTypeNamer.fieldName(member);
      buffer.writeln();
      buffer.writeln('class $variantClass extends $unionName {');
      buffer.writeln('  const $variantClass(this.$fieldName);');
      buffer.writeln('  final $memberClass $fieldName;');
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  /// Renders a Dart `abstract class` for a GraphQL interface type: declared
  /// fields become abstract final fields with mapped Dart types (FR-008).
  String interfaceRepresentation(GraphQLInterfaceType type) {
    final className = DartTypeNamer.className(type.name);
    final buffer = StringBuffer();
    buffer.writeln(
      '/// Dart representation of the GraphQL interface `${type.name}`.',
    );
    buffer.writeln('abstract class $className {');
    buffer.writeln('  const $className();');
    for (final field in type.fields) {
      final dartType = mapType(field.type);
      final fieldName = DartTypeNamer.fieldName(field.name);
      buffer.writeln('  final $dartType $fieldName;');
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Map a GraphQL field name to a Dart field name (camelCase, reserved
  /// words escaped — spec 037 FR-007).
  static String fieldName(String graphQLName) =>
      DartTypeNamer.fieldName(graphQLName);

  /// Map a GraphQL type name to a Dart class name (PascalCase, reserved
  /// built-in type collisions escaped — spec 037 FR-007).
  static String className(String graphQLName) =>
      DartTypeNamer.className(graphQLName);

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
