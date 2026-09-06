// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barcode_listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BarcodeListing _$BarcodeListingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BarcodeListing', json, ($checkedConvert) {
      final val = BarcodeListing(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        barcode: $checkedConvert('barcode', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$BarcodeListingToJson(BarcodeListing instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'barcode': instance.barcode,
    };
