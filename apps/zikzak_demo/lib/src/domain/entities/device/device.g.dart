// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Device', json, ($checkedConvert) {
      final val = Device(
        id: $checkedConvert('id', (v) => v as String?),
        deviceToken: $checkedConvert('deviceToken', (v) => v as String?),
        info: $checkedConvert(
          'info',
          (v) =>
              v == null ? null : DeviceInfo.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': ?instance.id,
  'deviceToken': ?instance.deviceToken,
  'info': ?instance.info?.toJson(),
};
