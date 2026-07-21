// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_query_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListQueryParams<T> _$ListQueryParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => $checkedCreate('ListQueryParams', json, ($checkedConvert) {
  final val = ListQueryParams<T>(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    search: $checkedConvert('search', (v) => v as String?),
    limit: $checkedConvert('limit', (v) => (v as num?)?.toInt()),
    offset: $checkedConvert('offset', (v) => (v as num?)?.toInt()),
  );
  return val;
});

Map<String, dynamic> _$ListQueryParamsToJson<T>(
  ListQueryParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'params': ?instance.params,
  'search': ?instance.search,
  'limit': ?instance.limit,
  'offset': ?instance.offset,
};
