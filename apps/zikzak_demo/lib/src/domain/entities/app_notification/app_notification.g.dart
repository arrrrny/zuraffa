// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AppNotification', json, ($checkedConvert) {
      final val = AppNotification(
        id: $checkedConvert('id', (v) => v as String),
        type: $checkedConvert('type', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String),
        targetType: $checkedConvert('targetType', (v) => v as String),
        targetId: $checkedConvert('targetId', (v) => v as String),
        read: $checkedConvert('read', (v) => v as bool),
        createdAt: $checkedConvert('createdAt', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$AppNotificationToJson(AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'body': instance.body,
      'targetType': instance.targetType,
      'targetId': instance.targetId,
      'read': instance.read,
      'createdAt': instance.createdAt,
    };
