import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for deleting an entity of type [T].
///
/// Use [DeleteParams] to wrap the unique identifier of an entity
/// during a delete operation.
@immutable
class DeleteParams<T> {
  /// The unique identifier of the entity to delete.
  final dynamic id;

  /// Optional additional parameters for the deletion.
  final Params? params;

  /// Create a [DeleteParams] instance.
  const DeleteParams(this.id, [this.params]);

  /// Create a copy of [DeleteParams] with optional new values.
  DeleteParams<T> copyWith({
    dynamic id,
    Params? params,
  }) {
    return DeleteParams<T>(
      id ?? this.id,
      params ?? this.params,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteParams<T> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          params == other.params;

  @override
  int get hashCode => id.hashCode ^ params.hashCode;

  @override
  String toString() => 'DeleteParams(id: $id, params: $params)';
}
