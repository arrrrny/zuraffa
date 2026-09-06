// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AppConfig', json, ($checkedConvert) {
      final val = AppConfig(
        id: $checkedConvert('id', (v) => v as String?),
        key: $checkedConvert('key', (v) => v as String),
        value: $checkedConvert('value', (v) => v as String?),
        description: $checkedConvert('description', (v) => v as String?),
        enabled: $checkedConvert('enabled', (v) => v as bool),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
  'id': instance.id,
  'key': instance.key,
  'value': ?instance.value,
  'description': ?instance.description,
  'enabled': instance.enabled,
  'updatedAt': ?instance.updatedAt?.toIso8601String(),
};
