// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'walkthrough_view.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalkthroughView _$WalkthroughViewFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WalkthroughView', json, ($checkedConvert) {
      final val = WalkthroughView(
        id: $checkedConvert('id', (v) => v as String?),
        walkthroughId: $checkedConvert('walkthroughId', (v) => v as String),
        stepIndex: $checkedConvert('stepIndex', (v) => (v as num).toInt()),
        completedAt: $checkedConvert(
          'completedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$WalkthroughViewToJson(WalkthroughView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'walkthroughId': instance.walkthroughId,
      'stepIndex': instance.stepIndex,
      'completedAt': ?instance.completedAt?.toIso8601String(),
    };
