// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInfo _$DeviceInfoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeviceInfo', json, ($checkedConvert) {
  final val = DeviceInfo(
    systemName: $checkedConvert('systemName', (v) => v as String?),
    deviceModel: $checkedConvert('deviceModel', (v) => v as String?),
    systemVersion: $checkedConvert('systemVersion', (v) => v as String?),
    deviceId: $checkedConvert('deviceId', (v) => v as String?),
    brand: $checkedConvert('brand', (v) => v as String?),
    manufacturer: $checkedConvert('manufacturer', (v) => v as String?),
    isPhysicalDevice: $checkedConvert('isPhysicalDevice', (v) => v as bool?),
    additionalProperties: $checkedConvert(
      'additionalProperties',
      (v) => v as Map<String, dynamic>?,
    ),
    os: $checkedConvert('os', (v) => $enumDecode(_$OperatingSystemEnumMap, v)),
  );
  return val;
});

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'systemName': ?instance.systemName,
      'deviceModel': ?instance.deviceModel,
      'systemVersion': ?instance.systemVersion,
      'deviceId': ?instance.deviceId,
      'brand': ?instance.brand,
      'manufacturer': ?instance.manufacturer,
      'isPhysicalDevice': ?instance.isPhysicalDevice,
      'additionalProperties': ?instance.additionalProperties,
      'os': _$OperatingSystemEnumMap[instance.os]!,
    };

const _$OperatingSystemEnumMap = {
  OperatingSystem.ios: 'ios',
  OperatingSystem.android: 'android',
  OperatingSystem.macos: 'macos',
  OperatingSystem.windows: 'windows',
  OperatingSystem.linux: 'linux',
  OperatingSystem.web: 'web',
};
