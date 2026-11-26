import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/toggle_params.part.dart';

/// Parameters for toggling a boolean field of an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [F] represents the field enum type.
///
/// Example: `ToggleParams<int, TodoFields>(id: 123, field: TodoFields.isCompleted, value: true)`
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $ToggleParams<I extends Object, F> implements $$Params {
  const $ToggleParams();

  /// The ID of the entity to update (strongly typed).
  I get id;

  /// The field to toggle.
  F get field;

  /// The target value for the field.
  ///
  /// Typed `dynamic` (not `bool`) because generated native-mock usecase
  /// tests pass a type-correct sample of the toggled field's declared type
  /// into `copyWithField(field, value)`; narrowing to `bool` would reject
  /// `String`/`int`/`double` id-field samples at compile time.
  Object? get value;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Trust-boundary wire codec for [ToggleParams] (v3 generic value types get no
/// generated codec).
extension ToggleParamsWireCodec<I extends Object, F> on ToggleParams<I, F> {
  /// Serialize to a wire map; [toI] encodes the id, [toF] the field value.
  Map<String, dynamic> toWire(
    Object? Function(I value) toI,
    Object? Function(F value) toF,
  ) => {
    'params': params,
    'id': toI(id),
    'field': field,
    'value': toF(value as F),
  };
}

/// Decode a [ToggleParams] from a wire map.
ToggleParams<I, F> toggleParamsFromWire<I extends Object, F>(
  Map<String, dynamic> raw,
  I Function(Object? json) fromI,
  F Function(Object? json) fromF,
) {
  return ToggleParams<I, F>.fromTrusted(
    params: raw['params'] as Map<String, dynamic>?,
    id: fromI(raw['id']),
    field: fromF(raw['field']),
    value: fromF(raw['value']),
  );
}
