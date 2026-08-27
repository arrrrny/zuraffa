// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toggle_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToggleParams<I, F> _$ToggleParamsFromJson<I, F>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
  F Function(Object? json) fromJsonF,
) => $checkedCreate('ToggleParams', json, ($checkedConvert) {
  final val = ToggleParams<I, F>(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    id: $checkedConvert('id', (v) => fromJsonI(v)),
    field: $checkedConvert('field', (v) => fromJsonF(v)),
    value: $checkedConvert('value', (v) => v),
  );
  return val;
});

Map<String, dynamic> _$ToggleParamsToJson<I, F>(
  ToggleParams<I, F> instance,
  Object? Function(I value) toJsonI,
  Object? Function(F value) toJsonF,
) => <String, dynamic>{
  'params': ?instance.params,
  'id': toJsonI(instance.id),
  'field': toJsonF(instance.field),
  'value': ?instance.value,
};
