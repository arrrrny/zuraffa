// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodoStats _$TodoStatsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TodoStats', json, ($checkedConvert) {
      final val = TodoStats(
        total: $checkedConvert('total', (v) => (v as num).toInt()),
        active: $checkedConvert('active', (v) => (v as num).toInt()),
        completed: $checkedConvert('completed', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$TodoStatsToJson(TodoStats instance) => <String, dynamic>{
  'total': instance.total,
  'active': instance.active,
  'completed': instance.completed,
};
