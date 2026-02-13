// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateParams<T> _$CreateParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => CreateParams<T>(
  params: json['params'] as Map<String, dynamic>?,
  data: fromJsonT(json['data']),
);

Map<String, dynamic> _$CreateParamsToJson<T>(
  CreateParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'params': instance.params,
  'data': toJsonT(instance.data),
};
