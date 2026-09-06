// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connected_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectedAccount _$ConnectedAccountFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConnectedAccount', json, ($checkedConvert) {
      final val = ConnectedAccount(
        id: $checkedConvert('id', (v) => v as String),
        retailerId: $checkedConvert('retailerId', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        status: $checkedConvert('status', (v) => v as String),
        lastSyncedAt: $checkedConvert('lastSyncedAt', (v) => v as String),
        createdAt: $checkedConvert('createdAt', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ConnectedAccountToJson(ConnectedAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'retailerId': instance.retailerId,
      'displayName': instance.displayName,
      'status': instance.status,
      'lastSyncedAt': instance.lastSyncedAt,
      'createdAt': instance.createdAt,
    };
