// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialization_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InitializationParams _$InitializationParamsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('InitializationParams', json, ($checkedConvert) {
  final val = InitializationParams(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    timeout: $checkedConvert(
      'timeout',
      (v) => DurationConverter.durationFromJson((v as num).toInt()),
    ),
    forceRefresh: $checkedConvert('forceRefresh', (v) => v as bool? ?? false),
    credentials: $checkedConvert(
      'credentials',
      (v) => v == null ? null : Credentials.fromJson(v as Map<String, dynamic>),
    ),
    settings: $checkedConvert(
      'settings',
      (v) => v == null ? null : Settings.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$InitializationParamsToJson(
  InitializationParams instance,
) => <String, dynamic>{
  'params': ?instance.params,
  'timeout': DurationConverter.durationToJson(instance.timeout),
  'forceRefresh': ?instance.forceRefresh,
  'credentials': ?instance.credentials?.toJson(),
  'settings': ?instance.settings?.toJson(),
};
