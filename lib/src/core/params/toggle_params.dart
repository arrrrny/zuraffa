import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/toggle_params.part.dart';

/// Parameters for toggling a boolean field of an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [F] represents the field descriptor type — in v3 a
/// `ZorphyField<E, Object?>` (a `<E>Fields` entry, value-erased via
/// `asObject`, zorphy#301), the write-capable descriptor the datasource
/// applies through `field.set(existing, value)`.
///
/// Example: `ToggleParams<int, ZorphyField<Todo, Object?>>(id: 123, field: TodoFields.isCompleted.asObject, value: true)`
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $ToggleParams<I extends Object, F> implements Params {
  const $ToggleParams();

  /// The ID of the entity to update (strongly typed).
  I get id;

  /// The field to toggle.
  F get field;

  /// The target value for the field.
  ///
  /// Typed `Object?` (not `bool`) because generated native-mock usecase
  /// tests pass a type-correct sample of the toggled field's declared type
  /// into `field.set(existing, value)`; narrowing to `bool` would reject
  /// `String`/`int`/`double` id-field samples at compile time.
  Object? get value;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Serialize a [ToggleParams] to a wire map; [toI] encodes the id, [toF] the field.
///
/// Hand-written rather than the generated `toWire` — see [createParamsToWire].
/// [value] is an independent `Object?` (it may be a `bool`, `String`, … that is
/// not an [F]); only [field] goes through [toF].
Map<String, dynamic> toggleParamsToWire<I extends Object, F>(
  ToggleParams<I, F> params, {
  required Object? Function(I value) toI,
  required Object? Function(F value) toF,
}) => {
  'params': params.params,
  'id': toI(params.id),
  'field': toF(params.field),
  'value': params.value,
};

/// Decode a [ToggleParams] from a wire map.
ToggleParams<I, F> toggleParamsFromWire<I extends Object, F>(
  Map<String, dynamic> raw,
  I Function(Object? json) fromI,
  F Function(Object? json) fromF,
) => ToggleParams<I, F>.fromTrusted(
  params: raw['params'] as Map<String, dynamic>?,
  id: fromI(raw['id']),
  field: fromF(raw['field']),
  value: raw['value'],
);
