// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorLog _$ErrorLogFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ErrorLog', json, ($checkedConvert) {
  final val = ErrorLog(
    id: $checkedConvert('id', (v) => v as String?),
    message: $checkedConvert('message', (v) => v as String),
    stackTrace: $checkedConvert('stackTrace', (v) => v as String),
    logLevel: $checkedConvert('logLevel', (v) => v as String),
    loggerName: $checkedConvert('loggerName', (v) => v as String?),
    userId: $checkedConvert('userId', (v) => v as String?),
    customerId: $checkedConvert('customerId', (v) => v as String?),
    deviceInfo: $checkedConvert(
      'deviceInfo',
      (v) => v as Map<String, dynamic>?,
    ),
    ipAddress: $checkedConvert('ipAddress', (v) => v as String?),
    appVersion: $checkedConvert('appVersion', (v) => v as String?),
    platform: $checkedConvert('platform', (v) => v as String?),
    timestamp: $checkedConvert('timestamp', (v) => DateTime.parse(v as String)),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$ErrorLogToJson(ErrorLog instance) => <String, dynamic>{
  'id': ?instance.id,
  'message': instance.message,
  'stackTrace': instance.stackTrace,
  'logLevel': instance.logLevel,
  'loggerName': ?instance.loggerName,
  'userId': ?instance.userId,
  'customerId': ?instance.customerId,
  'deviceInfo': ?instance.deviceInfo,
  'ipAddress': ?instance.ipAddress,
  'appVersion': ?instance.appVersion,
  'platform': ?instance.platform,
  'timestamp': instance.timestamp.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};
