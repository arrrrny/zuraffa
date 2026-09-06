// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'walkthrough_step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalkthroughStep _$WalkthroughStepFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WalkthroughStep', json, ($checkedConvert) {
      final val = WalkthroughStep(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String),
        imagePath: $checkedConvert('imagePath', (v) => v as String?),
        iconPath: $checkedConvert('iconPath', (v) => v as String?),
        order: $checkedConvert('order', (v) => (v as num).toInt()),
        buttonText: $checkedConvert('buttonText', (v) => v as String?),
        targetWidget: $checkedConvert('targetWidget', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$WalkthroughStepToJson(WalkthroughStep instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'imagePath': ?instance.imagePath,
      'iconPath': ?instance.iconPath,
      'order': instance.order,
      'buttonText': ?instance.buttonText,
      'targetWidget': ?instance.targetWidget,
    };
