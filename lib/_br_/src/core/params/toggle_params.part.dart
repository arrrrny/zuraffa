// dart format off
part of '../../../../src/core/params/toggle_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class ToggleParams<I extends Object, F> implements ZorphyValueBase {
  const ToggleParams.fromTrusted({
    required this.id,
    required this.field,
    this.value,
    this.params,
  });

  final I id;

  final F field;

  final Object? value;

  final Map<String, dynamic>? params;

  ToggleParams<I, F> copyWith({
    I? id,
    F? field,
    Object? value = _sentinel,
    Object? params = _sentinel,
  }) {
    return ToggleParams<I, F>.fromTrusted(
      id: id ?? this.id,
      field: field ?? this.field,
      value: identical(value, _sentinel) ? this.value : value as Object?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToggleParams &&
        this.id == other.id &&
        this.field == other.field &&
        this.value == other.value &&
        this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([id, field, value, params]);

  @override
  String toString() =>
      'ToggleParams(id: $id, field: $field, value: $value, params: $params)';
}

