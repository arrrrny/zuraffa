// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteParams<I> _$DeleteParamsFromJson<I>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
) => DeleteParams<I>(
  id: fromJsonI(json['id']),
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DeleteParamsToJson<I>(
  DeleteParams<I> instance,
  Object? Function(I value) toJsonI,
) => <String, dynamic>{
  'id': toJsonI(instance.id),
  'params': instance.params?.toJson(),
};
