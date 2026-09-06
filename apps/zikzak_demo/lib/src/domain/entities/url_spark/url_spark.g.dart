// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_spark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UrlSpark _$UrlSparkFromJson(Map<String, dynamic> json) => $checkedCreate(
  'UrlSpark',
  json,
  ($checkedConvert) {
    final val = UrlSpark(
      id: $checkedConvert('id', (v) => v as String?),
      url: $checkedConvert('url', (v) => v as String),
      metadata: $checkedConvert('metadata', (v) => v as Map<String, dynamic>?),
    );
    return val;
  },
);

Map<String, dynamic> _$UrlSparkToJson(UrlSpark instance) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'metadata': ?instance.metadata,
};
