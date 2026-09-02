// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Todo _$TodoFromJson(Map<String, dynamic> json) => $checkedCreate('Todo', json, (
  $checkedConvert,
) {
  final val = Todo(
    id: $checkedConvert('id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    isCompleted: $checkedConvert('isCompleted', (v) => v as bool),
    priority: $checkedConvert('priority', (v) => (v as num).toInt()),
    tags: $checkedConvert(
      'tags',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    completedAt: $checkedConvert(
      'completedAt',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$TodoToJson(Todo instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'isCompleted': instance.isCompleted,
  'priority': instance.priority,
  'tags': instance.tags,
  'createdAt': instance.createdAt.toIso8601String(),
  'completedAt': instance.completedAt.toIso8601String(),
};
