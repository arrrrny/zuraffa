// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Locale _$LocaleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Locale', json, ($checkedConvert) {
      final val = Locale(
        id: $checkedConvert('id', (v) => v as String),
        languageCode: $checkedConvert('languageCode', (v) => v as String),
        countryCode: $checkedConvert('countryCode', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$LocaleToJson(Locale instance) => <String, dynamic>{
  'id': instance.id,
  'languageCode': instance.languageCode,
  'countryCode': instance.countryCode,
};
