// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_form.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DynamicForm _$DynamicFormFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DynamicForm', json, ($checkedConvert) {
      final val = DynamicForm(
        id: $checkedConvert('id', (v) => v as String?),
        code: $checkedConvert('code', (v) => v as String),
        version: $checkedConvert('version', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$DynamicFormToJson(DynamicForm instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'version': instance.version,
      'name': instance.name,
      'description': ?instance.description,
    };
