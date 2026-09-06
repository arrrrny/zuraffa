// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Feedback _$FeedbackFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Feedback', json, ($checkedConvert) {
      final val = Feedback(
        id: $checkedConvert('id', (v) => v as String?),
        message: $checkedConvert('message', (v) => v as String),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$FeedbackTypeEnumMap, v),
        ),
        imageUrl: $checkedConvert('imageUrl', (v) => v as String?),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FeedbackToJson(Feedback instance) => <String, dynamic>{
  'id': ?instance.id,
  'message': instance.message,
  'type': _$FeedbackTypeEnumMap[instance.type]!,
  'imageUrl': ?instance.imageUrl,
  'createdAt': ?instance.createdAt?.toIso8601String(),
};

const _$FeedbackTypeEnumMap = {
  FeedbackType.error: 'error',
  FeedbackType.suggestion: 'suggestion',
  FeedbackType.thanks: 'thanks',
};
