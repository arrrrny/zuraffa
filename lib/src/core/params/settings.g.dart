// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Settings', json, ($checkedConvert) {
      final val = Settings(
        params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
      );
      return val;
    });

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
  'params': ?instance.params,
};
