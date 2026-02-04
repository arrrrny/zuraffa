import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for updating an entity with id and data of type [T].
@immutable
class UpdateParams<T> {
  /// The unique identifier of the entity to update.
  final dynamic id;

  /// The update data (e.g., a Partial map or a Zorphy Patch object).
  final T data;

  /// Optional additional parameters for the update.
  final Params? params;

  /// Create an [UpdateParams] instance.
  const UpdateParams({required this.id, required this.data, this.params});

  /// Validate that all keys in [data] are present in [validFields].
  ///
  /// Only applicable if [T] is a [Map].
  void validate(List<String> validFields) {
    if (data is Map) {
      final map = data as Map;
      for (final key in map.keys) {
        if (!validFields.contains(key)) {
          throw ArgumentError('Field "$key" is not a valid field for update.');
        }
      }
    }
  }

  /// Create a copy of [UpdateParams] with optional new values.
  UpdateParams<T> copyWith({dynamic id, T? data, Params? params}) {
    return UpdateParams<T>(
      id: id ?? this.id,
      data: data ?? this.data,
      params: params ?? this.params,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateParams<T> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          data == other.data &&
          params == other.params;

  @override
  int get hashCode => id.hashCode ^ data.hashCode ^ params.hashCode;

  @override
  String toString() => 'UpdateParams(id: $id, data: $data, params: $params)';
}
