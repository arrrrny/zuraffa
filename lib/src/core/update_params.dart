import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for updating an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [P] represents the patch type (`Zorphy Patch` or `Map<String, dynamic>`).
///
/// Example: `UpdateParams<int, TodoPatch>(id: 123, data: patch)`
///
/// This allows strongly-typed IDs and patch data instead of using `dynamic`.
@immutable
class UpdateParams<I, P> {
  /// The ID of the entity to update (strongly typed).
  final I id;

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
  UpdateParams<I, P> copyWith({
    I? id,
    P? data,
    Params? params,
    bool clearParams = false,
  }) {
    return UpdateParams<I, P>(
      id: id ?? this.id,
      data: data ?? this.data,
      params: clearParams ? null : (params ?? this.params),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateParams<I, P> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          data == other.data &&
          params == other.params;

  @override
  int get hashCode => id.hashCode ^ data.hashCode ^ params.hashCode;

  @override
  String toString() =>
      'UpdateParams<$I, $P>(id: $id, data: $data, params: $params)';
}
