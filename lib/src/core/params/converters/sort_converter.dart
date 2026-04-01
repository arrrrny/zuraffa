import 'package:zorphy_annotation/zorphy_annotation.dart';

typedef FieldResolver<T> = Field<T, dynamic>? Function(String fieldName);

/// Converter for [Sort] type.
///
/// Provides static methods for serializing and deserializing Zorphy Sort objects
/// with generic-aware helpers and optional field resolution to preserve
/// type-safety and matching behavior.
class SortConverter {
  SortConverter._();

  /// Serializes a [Sort] to JSON.
  static Map<String, dynamic>? toJson(Sort<dynamic>? sort) {
    return toJsonTyped<dynamic>(sort);
  }

  /// Serializes a typed [Sort] to JSON with clearer generic context.
  static Map<String, dynamic>? toJsonTyped<T>(Sort<T>? sort) {
    if (sort == null) return null;
    try {
      return sort.toJson();
    } catch (e) {
      throw ArgumentError(
        'Failed to serialize Sort<$T> to JSON: $e\n'
        'Ensure the Sort is a valid Zorphy-generated sort.',
      );
    }
  }

  /// Deserializes a [Sort] from JSON with optional field resolution.
  static Sort<dynamic>? fromJson(
    Map<String, dynamic>? json, [
    Map<String, Field<dynamic, dynamic>>? fields,
    FieldResolver<dynamic>? resolveField,
  ]) {
    return fromJsonTyped<dynamic>(json, fields, resolveField);
  }

  /// Deserializes a typed [Sort] from JSON with optional field resolution.
  ///
  /// Provide either a fields map or a resolver to enable matching; otherwise
  /// a fallback field is created that can read from map-backed entities.
  static Sort<T>? fromJsonTyped<T>(
    Map<String, dynamic>? json, [
    Map<String, Field<T, dynamic>>? fields,
    FieldResolver<T>? resolveField,
  ]) {
    if (json == null) return null;
    final fieldName = json['field'] as String?;
    if (fieldName == null) return null;
    final descending = json['descending'] as bool? ?? false;
    final field = _resolveField(fieldName, fields, resolveField);
    return Sort(field, descending: descending);
  }

  static Field<T, dynamic> _resolveField<T>(
    String fieldName,
    Map<String, Field<T, dynamic>>? fields,
    FieldResolver<T>? resolver,
  ) {
    final fromMap = fields?[fieldName];
    if (fromMap != null) return fromMap;
    final fromResolver = resolver?.call(fieldName);
    if (fromResolver != null) return fromResolver;
    return _createField<T>(fieldName);
  }

  static Field<T, dynamic> _createField<T>(String fieldName) {
    return Field<T, dynamic>(fieldName, (T entity) {
      if (entity is Map<String, dynamic>) {
        return entity[fieldName];
      }
      return _missingFieldGetter(fieldName);
    });
  }

  static Never _missingFieldGetter(String fieldName) {
    throw StateError(
      'Field getter not provided for "$fieldName". '
      'Provide a Field registry or resolver to enable matching.',
    );
  }
}
