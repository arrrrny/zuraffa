// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateParams<I, P> _$UpdateParamsFromJson<I, P>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
  P Function(Object? json) fromJsonP,
) => $checkedCreate('UpdateParams', json, ($checkedConvert) {
  final val = UpdateParams<I, P>(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    id: $checkedConvert('id', (v) => fromJsonI(v)),
    data: $checkedConvert('data', (v) => fromJsonP(v)),
  );
  return val;
});

Map<String, dynamic> _$UpdateParamsToJson<I, P>(
  UpdateParams<I, P> instance,
  Object? Function(I value) toJsonI,
  Object? Function(P value) toJsonP,
) => <String, dynamic>{
  'params': ?instance.params,
  'id': toJsonI(instance.id),
  'data': toJsonP(instance.data),
};
