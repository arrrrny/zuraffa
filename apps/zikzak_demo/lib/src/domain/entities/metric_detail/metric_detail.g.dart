// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metric_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MetricDetail _$MetricDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MetricDetail', json, ($checkedConvert) {
      final val = MetricDetail(
        name: $checkedConvert('name', (v) => v as String),
        score: $checkedConvert('score', (v) => (v as num).toInt()),
        label: $checkedConvert('label', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$MetricDetailToJson(MetricDetail instance) =>
    <String, dynamic>{
      'name': instance.name,
      'score': instance.score,
      'label': ?instance.label,
    };
