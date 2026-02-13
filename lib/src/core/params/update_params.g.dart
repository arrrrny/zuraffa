// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateParams<I, P> _$UpdateParamsFromJson<I, P>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
  P Function(Object? json) fromJsonP,
) => UpdateParams<I, P>(
  params: json['params'] as Map<String, dynamic>?,
  id: fromJsonI(json['id']),
  data: fromJsonP(json['data']),
);

Map<String, dynamic> _$UpdateParamsToJson<I, P>(
  UpdateParams<I, P> instance,
  Object? Function(I value) toJsonI,
  Object? Function(P value) toJsonP,
) => <String, dynamic>{
  'params': instance.params,
  'id': toJsonI(instance.id),
  'data': toJsonP(instance.data),
};
