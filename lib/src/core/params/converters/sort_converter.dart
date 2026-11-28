import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'filter_converter.dart';

/// Converter for [ZorphySort].
///
/// Serializes with [ZorphySort.toWire] and rebuilds with
/// [ZorphySort.fromWire]; a sort is only decoded against the entity's real
/// field registry, so its ordering always reads the real field.
class SortConverter {
  SortConverter._();

  /// Serializes a [ZorphySort] to JSON.
  static Map<String, dynamic>? toJson(ZorphySort<dynamic>? sort) =>
      toJsonTyped<dynamic>(sort);

  /// Serializes a typed [ZorphySort] with clearer generic context.
  static Map<String, dynamic>? toJsonTyped<T>(ZorphySort<T>? sort) {
    if (sort == null) return null;
    try {
      return sort.toWire();
    } catch (e) {
      throw ArgumentError(
        'Failed to serialize ZorphySort<$T> to JSON: $e\n'
        'Ensure the sort is a valid zorphy v3 ordering.',
      );
    }
  }

  /// Deserializes a [ZorphySort] from JSON; [resolve] as in
  /// [FilterConverter.fromJsonTyped].
  static ZorphySort<dynamic>? fromJson(
    Map<String, dynamic>? json,
    FieldResolver<dynamic> resolve,
  ) => fromJsonTyped<dynamic>(json, resolve);

  /// Deserializes a typed [ZorphySort] from JSON.
  static ZorphySort<T>? fromJsonTyped<T>(
    Map<String, dynamic>? json,
    FieldResolver<T> resolve,
  ) {
    if (json == null) return null;
    try {
      return ZorphySort.fromWire<T>(json, resolve);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw ArgumentError(
        'Failed to deserialize ZorphySort<$T> from JSON: $json\n'
        'Error: $e\n'
        'Provide a field registry (e.g. `<Entity>Fields.all.byPointer`).',
      );
    }
  }
}
