// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zik_zak_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ZikZakScore _$ZikZakScoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ZikZakScore', json, ($checkedConvert) {
      final val = ZikZakScore(
        id: $checkedConvert('id', (v) => v as String?),
        barcode: $checkedConvert('barcode', (v) => v as String?),
        url: $checkedConvert('url', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String?),
        totalScore: $checkedConvert('totalScore', (v) => (v as num).toInt()),
        authenticityScore: $checkedConvert(
          'authenticityScore',
          (v) => (v as num).toInt(),
        ),
        brandScore: $checkedConvert('brandScore', (v) => (v as num).toInt()),
        performanceScore: $checkedConvert(
          'performanceScore',
          (v) => (v as num).toInt(),
        ),
        valueScore: $checkedConvert('valueScore', (v) => (v as num).toInt()),
        competitionScore: $checkedConvert(
          'competitionScore',
          (v) => (v as num).toInt(),
        ),
        calculatedAt: $checkedConvert(
          'calculatedAt',
          (v) => DateTime.parse(v as String),
        ),
        isCached: $checkedConvert('isCached', (v) => v as bool),
        metrics: $checkedConvert(
          'metrics',
          (v) => (v as List<dynamic>)
              .map((e) => MetricDetail.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ZikZakScoreToJson(ZikZakScore instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'barcode': ?instance.barcode,
      'url': ?instance.url,
      'title': ?instance.title,
      'totalScore': instance.totalScore,
      'authenticityScore': instance.authenticityScore,
      'brandScore': instance.brandScore,
      'performanceScore': instance.performanceScore,
      'valueScore': instance.valueScore,
      'competitionScore': instance.competitionScore,
      'calculatedAt': instance.calculatedAt.toIso8601String(),
      'isCached': instance.isCached,
      'metrics': instance.metrics.map((e) => e.toJson()).toList(),
    };
