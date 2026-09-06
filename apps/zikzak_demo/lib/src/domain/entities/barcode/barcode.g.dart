// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barcode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Barcode _$BarcodeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Barcode', json, ($checkedConvert) {
      final val = Barcode(
        value: $checkedConvert('value', (v) => v as String),
        format: $checkedConvert(
          'format',
          (v) => $enumDecode(_$BarcodeFormatEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$BarcodeToJson(Barcode instance) => <String, dynamic>{
  'value': instance.value,
  'format': _$BarcodeFormatEnumMap[instance.format]!,
};

const _$BarcodeFormatEnumMap = {
  BarcodeFormat.ean13: 'ean13',
  BarcodeFormat.ean8: 'ean8',
  BarcodeFormat.upca: 'upca',
  BarcodeFormat.upce: 'upce',
};
