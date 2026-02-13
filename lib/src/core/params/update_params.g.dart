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
  id: fromJsonI(json['id']),
  data: fromJsonP(json['data']),
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UpdateParamsToJson<I, P>(
  UpdateParams<I, P> instance,
  Object? Function(I value) toJsonI,
  Object? Function(P value) toJsonP,
) => <String, dynamic>{
  'id': toJsonI(instance.id),
  'data': toJsonP(instance.data),
  'params': instance.params?.toJson(),
};
