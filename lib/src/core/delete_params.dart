import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for deleting an entity of type [T].
@immutable
class DeleteParams<T> {
  /// The ID of the entity to delete.
  final dynamic id;

  /// Optional additional parameters for the deletion.
  final Params? params;

  /// Create a [DeleteParams] instance.
  const DeleteParams({required this.id, this.params});

  /// Serializes the delete parameters to a flat map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{'id': id, if (params != null) ...?params!.params};
  }

  /// Create a copy of [DeleteParams] with optional new values.
  DeleteParams<T> copyWith({
    dynamic id,
    Params? params,
    bool clearParams = false,
  }) {
    return DeleteParams<T>(
      id: id ?? this.id,
      params: clearParams ? null : (params ?? this.params),
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
  String toString() => 'DeleteParams<$T>(id: $id, params: $params)';
}
