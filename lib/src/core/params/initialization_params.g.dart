// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialization_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InitializationParams _$InitializationParamsFromJson(
  Map<String, dynamic> json,
) => InitializationParams(
  timeout: Duration(microseconds: (json['timeout'] as num).toInt()),
  forceRefresh: json['forceRefresh'] as bool,
  params: json['params'] == null
      ? null
      : Params.fromJson(json['params'] as Map<String, dynamic>),
  credentials: json['credentials'] == null
      ? null
      : Params.fromJson(json['credentials'] as Map<String, dynamic>),
  settings: json['settings'] == null
      ? null
      : Params.fromJson(json['settings'] as Map<String, dynamic>),
);

Map<String, dynamic> _$InitializationParamsToJson(
  InitializationParams instance,
) => <String, dynamic>{
  'timeout': instance.timeout.inMicroseconds,
  'forceRefresh': instance.forceRefresh,
  'params': instance.params?.toJson(),
  'credentials': instance.credentials?.toJson(),
  'settings': instance.settings?.toJson(),
};
