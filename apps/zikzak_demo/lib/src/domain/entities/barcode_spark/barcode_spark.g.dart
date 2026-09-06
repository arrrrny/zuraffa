// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barcode_spark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BarcodeSpark _$BarcodeSparkFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BarcodeSpark', json, ($checkedConvert) {
      final val = BarcodeSpark(
        id: $checkedConvert('id', (v) => v as String?),
        barcode: $checkedConvert('barcode', (v) => v as String),
        sourceChannel: $checkedConvert('sourceChannel', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BarcodeSparkToJson(BarcodeSpark instance) =>
    <String, dynamic>{
      'id': instance.id,
      'barcode': instance.barcode,
      'sourceChannel': ?instance.sourceChannel,
    };
