// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UrlListing _$UrlListingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UrlListing', json, ($checkedConvert) {
      final val = UrlListing(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$UrlListingToJson(UrlListing instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'url': instance.url,
    };
