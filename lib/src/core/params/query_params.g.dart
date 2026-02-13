// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryParams<T> _$QueryParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => QueryParams<T>(
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
);

Map<String, dynamic> _$QueryParamsToJson<T>(
  QueryParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{'params': instance.params?.toJson()};
