// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialization_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InitializationParams _$InitializationParamsFromJson(
  Map<String, dynamic> json,
) => InitializationParams(
  params: json['params'] as Map<String, dynamic>?,
  timeout: json['timeout'] == null
      ? null
      : Duration(microseconds: (json['timeout'] as num).toInt()),
  forceRefresh: json['forceRefresh'] as bool?,
  credentials: json['credentials'] == null
      ? null
      : Credentials.fromJson(json['credentials'] as Map<String, dynamic>),
  settings: json['settings'] == null
      ? null
      : Settings.fromJson(json['settings'] as Map<String, dynamic>),
);

Map<String, dynamic> _$InitializationParamsToJson(
  InitializationParams instance,
) => <String, dynamic>{
  'params': instance.params,
  'timeout': instance.timeout.inMicroseconds,
  'forceRefresh': instance.forceRefresh,
  'credentials': instance.credentials?.toJson(),
  'settings': instance.settings?.toJson(),
};
