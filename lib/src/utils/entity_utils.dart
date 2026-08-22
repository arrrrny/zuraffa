// entity_utils.dart
//
// Helpers for the zfa entity CLI: type extraction from field-type strings
// used by [EntityTypeValidator] to decide whether a referenced type needs
// to exist on disk as an entity/enum (issue #296) or is a built-in that
// resolves without an on-disk declaration.

import 'package:zorphy/zorphy.dart' show FieldDefinition;

/// Dart core types (from `dart:core` and the SDK) that are NOT primitives
/// in the [EntityUtils._primitives] sense (String, int, ...) but that
/// still resolve without an on-disk entity/enum declaration and WITHOUT
/// any extra import — they are auto-imported by every Dart file via
/// `dart:core`.
///
/// Issue #411: previously a user writing
///   zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"
/// hit the on-disk validator, which rejected `Duration` with a misleading
/// "create an enum named Duration" error. Marking these types as
/// EXTERNAL (`isExternal: true`, see [EntityUtils.markDartCoreTypesAsExternal])
/// makes:
///   - [EntityTypeValidator] skip on-disk resolution for them,
///   - the zorphy [FieldNormalizer] skip `$`-prefixing them (so the
///     generated source carries `Duration get x;`, not `$Duration get x;`
///     which would not resolve),
///   - the zorphy [ImportResolver] skip emitting a bogus entity-style
///     import for them.
///
/// The list is intentionally narrow: only types whose membership is
/// stable across Dart SDK versions and that need NO import to resolve.
/// For types that DO need an import (e.g. `Offset` from `dart:ui`), users
/// must keep using the explicit `!Type` external-marker syntax so the
/// framework knows not to `$`-prefix and not to import-resolve.
const Set<String> dartCoreTypes = <String>{
  'Duration',
  'Uri',
  'BigInt',
};

class EntityUtils {
  /// The primitive / built-in Dart types that the zfa CLI treats as
  /// "no on-disk declaration needed" — referenced types are NOT
  /// entity/enum candidates when they appear in this set after stripping
  /// nullable (`?`) and generic wrappers (`List<...>`, `Map<...>`) and
  /// the Zorphy entity prefix (`$`).
  ///
  /// This set is the single source of truth consumed by
  /// [extractEntityTypes]; keep it in sync with the exclusion list there.
  static const Set<String> _primitives = <String>{
    'String',
    'int',
    'double',
    'bool',
    'DateTime',
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

  /// Extracts entity types from a field type string (e.g. `List<Product>`
  /// returns `['Product']`). Returns an empty list for primitives, for
  /// the entity being created itself (caller passes [selfEntityName]
  /// separately via [EntityTypeValidator]), and for the Dart core types
  /// in [dartCoreTypes].
  ///
  /// Issue #411: `Duration`, `Uri`, `BigInt` (and types in
  /// [dartCoreTypes]) are now treated as built-ins — `extractEntityTypes`
  /// returns an empty list for them so [EntityTypeValidator] does not
  /// reject the field as an unresolvable entity/enum reference.
  static List<String> extractEntityTypes(String fieldType) {
    final types = <String>{};
    _extractEntityTypesRecursive(fieldType, types);
    return types.toList();
  }

  /// Recursively extracts entity types from [fieldType], collecting them
  /// into [types]. Handles nested generics (List<List<T>>, Map<K, V>)
  /// and evaluates BOTH Map key and value types independently.
  static void _extractEntityTypesRecursive(
    String fieldType,
    Set<String> types,
  ) {
    var cleaned = fieldType.replaceAll('?', '');
    if (cleaned.startsWith('\$')) {
      cleaned = cleaned.substring(1);
    }

    // Unwrap List<T>
    if (cleaned.startsWith('List<') && cleaned.endsWith('>')) {
      final inner = cleaned.substring(5, cleaned.length - 1);
      _extractEntityTypesRecursive(inner, types);
      return;
    }

    // Unwrap Map<K, V> and recurse into BOTH key and value
    if (cleaned.startsWith('Map<') && cleaned.endsWith('>')) {
      final innerTypes = cleaned.substring(4, cleaned.length - 1);
      final typeParts = _smartSplitTopLevel(innerTypes);
      if (typeParts.length == 2) {
        _extractEntityTypesRecursive(typeParts[0], types); // KEY
        _extractEntityTypesRecursive(typeParts[1], types); // VALUE
      }
      return;
    }

    // Base case: no more wrappers, check if it's an entity type
    final baseType = cleaned.trim();
    if (baseType.isNotEmpty &&
        !_primitives.contains(baseType) &&
        !dartCoreTypes.contains(baseType) &&
        baseType[0].toUpperCase() == baseType[0]) {
      types.add(baseType);
    }
  }

  /// Returns the base type of [type] after stripping nullable (`?`) and
  /// generic wrappers (`List<...>`, `Map<K, V>` returns V). Used to detect
  /// Dart core types hidden inside generics, e.g. `List<Duration>` should
  /// be treated as having a `Duration` base type for [dartCoreTypes]
  /// membership.
  ///
  /// Examples:
  ///   - `Duration` -> `Duration`
  ///   - `Duration?` -> `Duration`
  ///   - `List<Duration>` -> `Duration`
  ///   - `Map<String, Duration>` -> `Duration`
  ///   - `List<Duration>?` -> `Duration`
  ///   - `Map<String, Duration>?` -> `Duration`
  ///   - `Map<String, List<Duration>>` -> `Duration`
  ///   - `List<List<Duration>>` -> `Duration`
  ///   - `Map<String, Map<String, Duration>>` -> `Duration`
  ///   - `String` -> `String`
  ///   - `int?` -> `int`
  static String extractBaseType(String type) {
    var baseType = type.replaceAll('?', '');
    var unwrapped = false;
    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      baseType = baseType.substring(5, baseType.length - 1);
      unwrapped = true;
    } else if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      final innerTypes = baseType.substring(4, baseType.length - 1);
      // Bracket-aware split so a Map<String, Map<String, Duration>> does
      // not break on the inner comma — see issue #411 nested-generics
      // test cases.
      final typeParts = _smartSplitTopLevel(innerTypes);
      if (typeParts.length == 2) {
        baseType = typeParts[1];
        unwrapped = true;
      }
    }
    if (baseType.startsWith('\$')) {
      baseType = baseType.substring(1);
    }
    // Strip any remaining generic parameters on the inner type (e.g.
    // `Map<String, List<Duration>>` -> Map-extract gives `List<Duration>`
    // -> recurse so we end up with `Duration`). Only recurse if we
    // actually unwrapped something above — otherwise we'd infinitely
    // recurse on unsupported generics like `Future<Duration>` or invalid
    // Map arity like `Map<A,B,C>`.
    if (unwrapped && baseType.contains('<') && baseType.endsWith('>')) {
      return extractBaseType(baseType);
    }
    return baseType.trim();
  }

  /// Splits [input] on top-level commas — commas inside `<...>` are
  /// preserved. Mirrors the bracket-depth logic used by zorphy's
  /// `NamingUtils.smartSplit`, kept local so this file has no other
  /// dependency.
  static List<String> _smartSplitTopLevel(String input) {
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '<') {
        depth++;
        current.write(char);
      } else if (char == '>') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        final part = current.toString().trim();
        if (part.isNotEmpty) parts.add(part);
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    final tail = current.toString().trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts;
  }

  /// Returns `true` when [type] is a Dart core type (per [dartCoreTypes])
  /// — either directly (`Duration`), inside a List (`List<Duration>`), or
  /// as the value type of a Map (`Map<String, Duration>`). Recurses into
  /// nested generics.
  ///
  /// IMPORTANT: per constraint in Bug C fix, this returns `true` ONLY when
  /// EVERY leaf type in [type] is a primitive or a member of [dartCoreTypes].
  /// Mixed fields like `Map<Product, Duration>` return `false` so the
  /// entity portion (`Product`) still gets normal validation/import resolution.
  static bool isDartCoreType(String type) {
    // Collect all entity types referenced by this field
    final entityTypes = extractEntityTypes(type);
    // If ANY entity type is found (i.e., a non-primitive, non-dartCoreTypes
    // leaf exists), the field is NOT purely a dart-core type.
    if (entityTypes.isNotEmpty) return false;

    // No entity types found — check if at least one leaf is a dartCoreTypes member
    final baseType = extractBaseType(type);
    return dartCoreTypes.contains(baseType);
  }

  /// Marks fields whose base type is a Dart core type (per [dartCoreTypes])
  /// as EXTERNAL — i.e. sets [FieldDefinition.isExternal] to `true` for
  /// them. Returns a new list; the input is not mutated. Fields already
  /// marked external are left unchanged.
  ///
  /// Issue #411: this is the single point that lets `zfa entity create`
  /// accept fields like `wallClockTimeout:Duration` (or `tags:List<Duration>`)
  /// — the external marker makes:
  ///   - [EntityTypeValidator] skip on-disk resolution (it already does
  ///     for external fields, issue #349),
  ///   - the zorphy [FieldNormalizer] skip `$`-prefixing (so the source
  ///     carries `Duration`, not `$Duration` which would not resolve),
  ///   - the zorphy [ImportResolver] skip emitting a bogus entity-style
  ///     import for `dart:core` types.
  ///
  /// The list [dartCoreTypes] is intentionally narrow — only types whose
  /// membership is stable across Dart SDK versions AND that need no
  /// import to resolve. For other types that live outside the entity
  /// tree but need an explicit import (e.g. `Offset` from `dart:ui`,
  /// `WebUri` from a plugin wrapper), users must keep using the explicit
  /// `!Type` external-marker syntax so they remain in control of the
  /// import.
  static List<FieldDefinition> markDartCoreTypesAsExternal(
    List<FieldDefinition> fields,
  ) {
    return fields.map((field) {
      if (field.isExternal) return field;
      if (isDartCoreType(field.type)) {
        return field.copyWith(isExternal: true);
      }
      return field;
    }).toList();
  }
}
