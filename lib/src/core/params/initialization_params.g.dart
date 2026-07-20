// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialization_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$InitializationParamsToJson(
  InitializationParams instance,
) => <String, dynamic>{
  'params': ?instance.params,
  'timeout': DurationConverter.durationToJson(instance.timeout),
  'forceRefresh': ?instance.forceRefresh,
  'credentials': ?instance.credentials?.toJson(),
  'settings': ?instance.settings?.toJson(),
  'hashCode': instance.hashCode,
};
