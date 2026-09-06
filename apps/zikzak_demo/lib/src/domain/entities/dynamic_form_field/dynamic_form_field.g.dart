// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_form_field.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DynamicFormField _$DynamicFormFieldFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DynamicFormField', json, ($checkedConvert) {
      final val = DynamicFormField(
        id: $checkedConvert('id', (v) => v as String?),
        code: $checkedConvert('code', (v) => v as String),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$DynamicFormFieldTypeEnumMap, v),
        ),
        label: $checkedConvert('label', (v) => v as String),
        placeholder: $checkedConvert('placeholder', (v) => v as String?),
        required: $checkedConvert('required', (v) => v as bool),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DynamicFormFieldToJson(DynamicFormField instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'type': _$DynamicFormFieldTypeEnumMap[instance.type]!,
      'label': instance.label,
      'placeholder': ?instance.placeholder,
      'required': instance.required,
      'options': ?instance.options,
    };

const _$DynamicFormFieldTypeEnumMap = {
  DynamicFormFieldType.text: 'text',
  DynamicFormFieldType.number: 'number',
  DynamicFormFieldType.select: 'select',
  DynamicFormFieldType.checkbox: 'checkbox',
  DynamicFormFieldType.date: 'date',
  DynamicFormFieldType.rating: 'rating',
  DynamicFormFieldType.slider: 'slider',
};
