// dart format off
part of '../../../../src/core/params/update_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class UpdateParams<I, P> implements ZorphyValueBase {
  const UpdateParams.fromTrusted({
    required this.id,
    required this.data,
    this.params,
  });

  final I id;

  final P data;

  final Map<String, dynamic>? params;

  UpdateParams<I, P> copyWith({I? id, P? data, Object? params = _sentinel}) {
    return UpdateParams<I, P>.fromTrusted(
      id: id ?? this.id,
      data: data ?? this.data,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateParams &&
        this.id == other.id &&
        this.data == other.data &&
        this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([id, data, params]);

  @override
  String toString() => 'UpdateParams(id: $id, data: $data, params: $params)';
}

