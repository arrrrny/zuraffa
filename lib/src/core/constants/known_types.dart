/// Known type names that should not be treated as entities for import generation.
///
/// These types are either:
/// - Built-in Dart types
/// - Zuraffa framework types (params, result, failure)
/// - Common types that don't need entity imports
class KnownTypes {
  KnownTypes._();

  /// Dart built-in primitive types
  static const dartPrimitives = [
    'int',
    'double',
    'bool',
    'String',
    'void',
    'dynamic',
  ];

  /// Dart collection types
  static const dartCollections = ['List', 'Map', 'Set'];

  /// Common Dart types that don't need imports
  static const dartTypes = [
    'Duration',
    'DateTime',
    'Uri',
    'BigInt',
    'Uint8List',
  ];

  /// Zuraffa parameter types
  static const zuraffaParams = [
    'NoParams',
    'Params',
    'QueryParams',
    'ListQueryParams',
    'UpdateParams',
    'DeleteParams',
    'CreateParams',
    'InitializationParams',
    'Partial',
    'ToggleParams',
  ];

  /// Zuraffa result and failure types
  static const zuraffaResults = ['Result', 'AppFailure'];

  /// Zorphy query/framework types (re-exported by zuraffa.dart via
  /// zorphy_annotation). These are NOT entities and must not trigger entity
  /// imports — e.g. `Field<Entity, dynamic>` appears as a type argument in
  /// `ToggleParams` and would otherwise produce a spurious
  /// `domain/entities/field/field.dart` import. (#292)
  static const zorphyTypes = [
    'Field',
    'Eq',
    'Filter',
    'Sort',
    'SortOrder',
    'FilterOperator',
  ];

  /// All types that should be excluded from entity import generation
  static const allExcluded = [
    ...dartPrimitives,
    ...dartCollections,
    ...dartTypes,
    ...zuraffaParams,
    ...zuraffaResults,
    ...zorphyTypes,
  ];

  /// Check if a type name should be excluded from entity imports
  static bool isExcluded(String typeName) {
    return allExcluded.contains(typeName);
  }

  /// Check if a type name is a Zuraffa parameter type
  static bool isZuraffaParam(String typeName) {
    return zuraffaParams.contains(typeName);
  }

  /// Check if a type name is a Dart primitive type
  static bool isDartPrimitive(String typeName) {
    return dartPrimitives.contains(typeName);
  }
}
