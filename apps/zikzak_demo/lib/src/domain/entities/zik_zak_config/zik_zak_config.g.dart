// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zik_zak_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ZikZakConfig _$ZikZakConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ZikZakConfig', json, ($checkedConvert) {
      final val = ZikZakConfig(
        id: $checkedConvert('id', (v) => v as String?),
        environment: $checkedConvert('environment', (v) => v as String),
        mode: $checkedConvert('mode', (v) => v as String),
        logLevel: $checkedConvert('logLevel', (v) => v as String),
        locale: $checkedConvert(
          'locale',
          (v) => Locale.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ZikZakConfigToJson(ZikZakConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'environment': instance.environment,
      'mode': instance.mode,
      'logLevel': instance.logLevel,
      'locale': instance.locale.toJson(),
    };
