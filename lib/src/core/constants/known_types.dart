/// Known type names that should not be treated as entities for import generation.
///
/// These types are either:
/// - Built-in Dart types
/// - Zuraffa framework types (params, result, failure)
/// - Common types that don't need entity imports
class KnownTypes {
  KnownTypes._();

  /// Dart built-in primitive types. `Object` belongs here: it is the value
  /// type of an erased `ZorphyField<E, Object?>` (zorphy#301), so it reaches
  /// the import resolver as a type argument and must never resolve to an
  /// `entities/object/object.dart` import.
  static const dartPrimitives = [
    'int',
    'double',
    'bool',
    'String',
    'void',
    'dynamic',
    'num',
    'Object',
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
    'Partial',
    'ToggleParams',
  ];

  /// Zuraffa result and failure types
  static const zuraffaResults = ['Result', 'AppFailure'];

  /// Zorphy query/framework types (re-exported by zuraffa.dart via
  /// zorphy_annotation). These are NOT entities and must not trigger entity
  /// imports — e.g. `ZorphyField<Entity, Object?>` appears as a type argument
  /// in `ToggleParams` and would otherwise produce a spurious
  /// `domain/entities/zorphy_field/zorphy_field.dart` import. (#292, #301)
  ///
  /// The v3 surface is uniformly `Zorphy`-prefixed (`ZorphyField`,
  /// `ZorphyLens`, `ZorphyFilter`, `ZorphySort`, `ZorphyPatch`,
  /// `ZorphyBoundaryResult`, the annotations…), so the prefix IS the
  /// vocabulary — a hand-kept list would go stale the next time zorphy
  /// adds a type. The names below are the v3 types that carry no prefix.
  static const zorphyTypes = [
    // v2 names, still excluded: a consumer's own signatures may name them.
    'Field',
    'Eq',
    'Filter',
    'Sort',
    'SortOrder',
    'FilterOperator',
    // v3 patch algebra (no prefix).
    'Patch',
    'PatchBase',
    'PatchNested',
    'PatchSet',
    'PatchUnchanged',
    'PatchValue',
    // v3 boundary results / violations (no prefix).
    'BoundaryErr',
    'BoundaryOk',
    'FieldViolation',
  ];

  /// The `Zorphy` prefix every prefixed v3 framework type carries.
  static const zorphyPrefix = 'Zorphy';

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
    return allExcluded.contains(typeName) || typeName.startsWith(zorphyPrefix);
  }

  /// Check if a type name is a Zuraffa parameter type
  static bool isZuraffaParam(String typeName) {
    return zuraffaParams.contains(typeName);
  }

  /// Check if a type name is a Zuraffa result/failure type
  static bool isZuraffaResult(String typeName) {
    return zuraffaResults.contains(typeName);
  }

  /// Check if a type name is a Zorphy framework type
  static bool isZorphyType(String typeName) {
    return zorphyTypes.contains(typeName);
  }

  /// Check if a type name is a Dart primitive type
  static bool isDartPrimitive(String typeName) {
    return dartPrimitives.contains(typeName);
  }
}
