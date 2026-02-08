import 'package:meta/meta.dart';
import 'package:zorphy/zorphy.dart';
import 'params.dart';

/// Parameters for creating a new entity of type [T].
///
/// The type parameter [T] represents the entity type being created.
@immutable
class CreateParams<T> {
  /// The entity data to create.
  final T data;

  /// Optional additional parameters for the creation.
  final Params? params;

  /// Create a [CreateParams] instance.
  const CreateParams({required this.data, this.params});

  /// Serializes the create parameters to a flat map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'data': data,
      if (params != null) ...?params!.params,
    };
  }

  /// Create a copy of [CreateParams] with optional new values.
  CreateParams<T> copyWith({
    T? data,
    Params? params,
    bool clearParams = false,
  }) {
    return CreateParams<T>(
      data: data ?? this.data,
      params: clearParams ? null : (params ?? this.params),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateParams<T> &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          params == other.params;

  @override
  int get hashCode => data.hashCode ^ params.hashCode;

  @override
  String toString() => 'CreateParams<$T>(data: $data, params: $params)';
}
