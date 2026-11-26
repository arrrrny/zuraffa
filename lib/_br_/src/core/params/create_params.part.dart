// dart format off
part of '../../../../src/core/params/create_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class CreateParams<T> implements ZorphyValueBase {
  const CreateParams.fromTrusted({required this.data, this.params});

  final T data;

  final Map<String, dynamic>? params;

  CreateParams<T> copyWith({T? data, Object? params = _sentinel}) {
    return CreateParams<T>.fromTrusted(
      data: data ?? this.data,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateParams &&
        this.data == other.data &&
        this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([data, params]);

  @override
  String toString() => 'CreateParams(data: $data, params: $params)';
}

