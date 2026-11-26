// dart format off
part of '../../../../src/core/params/toggle_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class ToggleParams<I, F> implements ZorphyValueBase {
  const ToggleParams.fromTrusted({
    required this.id,
    required this.field,
    required this.value,
  });

  final I id;

  final F field;

  final dynamic value;

  ToggleParams<I, F> copyWith({I? id, F? field, dynamic? value}) {
    return ToggleParams<I, F>.fromTrusted(
      id: id ?? this.id,
      field: field ?? this.field,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToggleParams &&
        this.id == other.id &&
        this.field == other.field &&
        this.value == other.value;
  }

  @override
  int get hashCode => Object.hashAll([id, field, value]);

  @override
  String toString() => 'ToggleParams(id: $id, field: $field, value: $value)';
}

