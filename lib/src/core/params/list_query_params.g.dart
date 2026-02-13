// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_query_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListQueryParams<T> _$ListQueryParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => ListQueryParams<T>(
  search: json['search'] as String?,
  limit: (json['limit'] as num?)?.toInt(),
  offset: (json['offset'] as num?)?.toInt(),
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ListQueryParamsToJson<T>(
  ListQueryParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'search': instance.search,
  'limit': instance.limit,
  'offset': instance.offset,
  'params': instance.params?.toJson(),
};
