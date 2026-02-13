// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateParams<T> _$CreateParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => CreateParams<T>(
  data: fromJsonT(json['data']),
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CreateParamsToJson<T>(
  CreateParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'data': toJsonT(instance.data),
  'params': instance.params?.toJson(),
};
