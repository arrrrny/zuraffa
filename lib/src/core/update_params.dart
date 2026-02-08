import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for updating an entity of type [T].
///
/// The type parameter [T] represents the entity type being updated,
/// and [P] represents the patch type (`Zorphy Patch` or `Map<String, dynamic>`).
@immutable
class UpdateParams<T, P> {
  /// The ID of the entity to update.
  final dynamic id;

  /// The patch data to apply (Zorphy Patch or Partial map).
  final P data;

  /// Optional additional parameters for the update.
  final Params? params;

  /// Create an [UpdateParams] instance.
  const UpdateParams({required this.id, required this.data, this.params});

  /// Serializes the update parameters to a flat map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'data': data,
      if (params != null) ...?params!.params,
    };
  }

  /// Create a copy of [UpdateParams] with optional new values.
  UpdateParams<T, P> copyWith({
    dynamic id,
    P? data,
    Params? params,
    bool clearParams = false,
  }) {
    return UpdateParams<T, P>(
      id: id ?? this.id,
      data: data ?? this.data,
      params: clearParams ? null : (params ?? this.params),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateParams<T, P> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          data == other.data &&
          params == other.params;

  @override
  int get hashCode => id.hashCode ^ data.hashCode ^ params.hashCode;

  @override
  String toString() =>
      'UpdateParams<$T, $P>(id: $id, data: $data, params: $params)';
}
