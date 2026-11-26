// dart format off
part of '../../../../src/core/params/delete_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class DeleteParams<I extends Object> implements ZorphyValueBase {
  const DeleteParams.fromTrusted({required this.id, this.params});

  final I id;

  final Map<String, dynamic>? params;

  DeleteParams<I> copyWith({I? id, Object? params = _sentinel}) {
    return DeleteParams<I>.fromTrusted(
      id: id ?? this.id,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteParams &&
        this.id == other.id &&
        this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([id, params]);

  @override
  String toString() => 'DeleteParams(id: $id, params: $params)';
}

