// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormOption _$FormOptionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FormOption', json, ($checkedConvert) {
      final val = FormOption(
        id: $checkedConvert('id', (v) => v as String?),
        value: $checkedConvert('value', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$FormOptionToJson(FormOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'label': instance.label,
    };
