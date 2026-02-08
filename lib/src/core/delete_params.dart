import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for deleting an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// This allows strongly-typed IDs instead of using `dynamic`.
@immutable
class DeleteParams<I> {
  /// The ID of the entity to delete (strongly typed).
  final I id;

  /// Optional additional parameters for the deletion.
  final Params? params;

  /// Create a [DeleteParams] instance.
  const DeleteParams({required this.id, this.params});

  /// Serializes the delete parameters to a flat map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{'id': id, if (params != null) ...?params!.params};
  }

  /// Create a copy of [DeleteParams] with optional new values.
  DeleteParams<I> copyWith({I? id, Params? params, bool clearParams = false}) {
    return DeleteParams<I>(
      id: id ?? this.id,
      params: clearParams ? null : (params ?? this.params),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteParams<I> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          params == other.params;

  @override
  int get hashCode => id.hashCode ^ params.hashCode;

  @override
  String toString() => 'DeleteParams<$I>(id: $id, params: $params)';
}
