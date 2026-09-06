// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_spark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextSpark _$TextSparkFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TextSpark', json, ($checkedConvert) {
      final val = TextSpark(
        id: $checkedConvert('id', (v) => v as String?),
        text: $checkedConvert('text', (v) => v as String),
        sourceChannel: $checkedConvert('sourceChannel', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$TextSparkToJson(TextSpark instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'sourceChannel': ?instance.sourceChannel,
};
