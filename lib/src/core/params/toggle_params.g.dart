// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toggle_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToggleParams<I, F> _$ToggleParamsFromJson<I, F>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
  F Function(Object? json) fromJsonF,
) => ToggleParams<I, F>(
  params: json['params'] as Map<String, dynamic>?,
  id: fromJsonI(json['id']),
  field: fromJsonF(json['field']),
  value: json['value'] as bool,
);

Map<String, dynamic> _$ToggleParamsToJson<I, F>(
  ToggleParams<I, F> instance,
  Object? Function(I value) toJsonI,
  Object? Function(F value) toJsonF,
) => <String, dynamic>{
  'params': ?instance.params,
  'id': toJsonI(instance.id),
  'field': toJsonF(instance.field),
  'value': instance.value,
};
