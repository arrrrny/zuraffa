// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextListing _$TextListingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TextListing', json, ($checkedConvert) {
      final val = TextListing(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        search: $checkedConvert('search', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$TextListingToJson(TextListing instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'search': instance.search,
    };
