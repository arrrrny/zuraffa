// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zik_zak.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ZikZak _$ZikZakFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ZikZak', json, ($checkedConvert) {
      final val = ZikZak(
        id: $checkedConvert('id', (v) => v as String?),
        spark: $checkedConvert(
          'spark',
          (v) => TextSpark.fromJson(v as Map<String, dynamic>),
        ),
        listing: $checkedConvert(
          'listing',
          (v) => Listing.fromJson(v as Map<String, dynamic>),
        ),
        origin: $checkedConvert(
          'origin',
          (v) => $enumDecode(_$ZikZakOriginEnumMap, v),
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ZikZakToJson(ZikZak instance) => <String, dynamic>{
  'id': instance.id,
  'spark': instance.spark.toJson(),
  'listing': instance.listing.toJson(),
  'origin': _$ZikZakOriginEnumMap[instance.origin]!,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$ZikZakOriginEnumMap = {
  ZikZakOrigin.barcode: 'barcode',
  ZikZakOrigin.url: 'url',
  ZikZakOrigin.text: 'text',
  ZikZakOrigin.share: 'share',
};
