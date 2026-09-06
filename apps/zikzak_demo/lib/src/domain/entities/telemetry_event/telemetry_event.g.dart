// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelemetryEvent _$TelemetryEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TelemetryEvent', json, ($checkedConvert) {
      final val = TelemetryEvent(
        id: $checkedConvert('id', (v) => v as String?),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$TelemetryEventTypeEnumMap, v),
        ),
        value: $checkedConvert('value', (v) => v as String),
        context: $checkedConvert('context', (v) => v as Map<String, dynamic>?),
      );
      return val;
    });

Map<String, dynamic> _$TelemetryEventToJson(TelemetryEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$TelemetryEventTypeEnumMap[instance.type]!,
      'value': instance.value,
      'context': ?instance.context,
    };

const _$TelemetryEventTypeEnumMap = {
  TelemetryEventType.screen_view: 'screen_view',
  TelemetryEventType.action: 'action',
  TelemetryEventType.error: 'error',
  TelemetryEventType.network: 'network',
};
