// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'walkthrough.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Walkthrough _$WalkthroughFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Walkthrough', json, ($checkedConvert) {
      final val = Walkthrough(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        version: $checkedConvert('version', (v) => v as String),
        steps: $checkedConvert(
          'steps',
          (v) => (v as List<dynamic>)
              .map((e) => WalkthroughStep.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        isCompleted: $checkedConvert('isCompleted', (v) => v as bool),
        completedAt: $checkedConvert(
          'completedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        currentStepId: $checkedConvert('currentStepId', (v) => v as String?),
        currentStepIndex: $checkedConvert(
          'currentStepIndex',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$WalkthroughToJson(Walkthrough instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'version': instance.version,
      'steps': instance.steps.map((e) => e.toJson()).toList(),
      'isCompleted': instance.isCompleted,
      'completedAt': ?instance.completedAt?.toIso8601String(),
      'currentStepId': ?instance.currentStepId,
      'currentStepIndex': instance.currentStepIndex,
    };
