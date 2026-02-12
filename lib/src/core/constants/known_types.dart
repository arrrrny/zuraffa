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
  static const dartTypes = ['Duration', 'DateTime'];

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
  ];

  /// Zuraffa result and failure types
  static const zuraffaResults = ['Result', 'AppFailure'];

  /// All types that should be excluded from entity import generation
  static const allExcluded = [
    ...dartPrimitives,
    ...dartCollections,
    ...dartTypes,
    ...zuraffaParams,
    ...zuraffaResults,
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
