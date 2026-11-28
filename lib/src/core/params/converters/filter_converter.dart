import 'package:zorphy_annotation/zorphy_annotation.dart';

/// Resolves a field pointer (e.g. `/price`) to the entity's erased
/// [ZorphyField] — the shape [ZorphyFilter.fromWire] and [ZorphySort.fromWire]
/// both take, and exactly what `<Entity>Fields.all.byPointer` provides.
typedef FieldResolver<T> = ZorphyField<T, Object?>? Function(String pointer);

/// Converter for [ZorphyFilter].
///
/// Serializes with the predicate's own [ZorphyFilter.toWire] and rebuilds
/// with [ZorphyFilter.fromWire] — the total decode layer zorphy ships. The
/// v2 hand-written `_deserializeFilter` tree (and its `Map`-backed fallback
/// field whose getter threw for typed entities) is gone: a wire filter is
/// only ever decoded against the entity's real registry, so a decoded
/// predicate is always a write-safe, match-correct one.
///
/// ```dart
/// final wire = FilterConverter.toJson(ProductFields.price.lessThan(100));
/// final back = FilterConverter.fromJsonTyped<Product>(
///   wire, ProductFields.all.byPointer);
/// ```
class FilterConverter {
  FilterConverter._();

  /// Serializes a [ZorphyFilter] to its wire map.
  static Map<String, dynamic>? toJson(ZorphyFilter<dynamic>? filter) =>
      toJsonTyped<dynamic>(filter);

  /// Serializes a typed [ZorphyFilter] while keeping [T] for error context.
  static Map<String, dynamic>? toJsonTyped<T>(ZorphyFilter<T>? filter) {
    if (filter == null) return null;
    try {
      return filter.toWire();
    } catch (e) {
      throw ArgumentError(
        'Failed to serialize ZorphyFilter<$T> to JSON: $e\n'
        'Ensure the filter is a valid zorphy v3 predicate.',
      );
    }
  }

  /// Deserializes a [ZorphyFilter] from its wire map.
  ///
  /// [resolve] maps a field pointer back to a [ZorphyField]; the generated
  /// `<Entity>Fields.all.byPointer` is the canonical resolver. Unknown
  /// pointers and unknown ops throw [FormatException] (a silently-mismatched
  /// predicate is worse than a loud one — zorphy's own contract).
  static ZorphyFilter<dynamic>? fromJson(
    Map<String, dynamic>? json,
    FieldResolver<dynamic> resolve,
  ) => fromJsonTyped<dynamic>(json, resolve);

  /// Deserializes a typed [ZorphyFilter] from its wire map.
  static ZorphyFilter<T>? fromJsonTyped<T>(
    Map<String, dynamic>? json,
    FieldResolver<T> resolve,
  ) {
    if (json == null) return null;
    try {
      return ZorphyFilter.fromWire<T>(json, resolve);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw ArgumentError(
        'Failed to deserialize ZorphyFilter<$T> from JSON: $json\n'
        'Error: $e\n'
        'Provide a field registry (e.g. `<Entity>Fields.all.byPointer`).',
      );
    }
  }
}
