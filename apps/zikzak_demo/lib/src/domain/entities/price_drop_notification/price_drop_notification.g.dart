// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_drop_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceDropNotification _$PriceDropNotificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PriceDropNotification', json, ($checkedConvert) {
  final val = PriceDropNotification(
    id: $checkedConvert('id', (v) => v as String),
    priceAlertId: $checkedConvert('priceAlertId', (v) => v as String),
    listingId: $checkedConvert('listingId', (v) => v as String),
    listingTitle: $checkedConvert('listingTitle', (v) => v as String),
    listingImageUrl: $checkedConvert('listingImageUrl', (v) => v as String?),
    oldPrice: $checkedConvert('oldPrice', (v) => (v as num).toDouble()),
    newPrice: $checkedConvert('newPrice', (v) => (v as num).toDouble()),
    dropPercentage: $checkedConvert(
      'dropPercentage',
      (v) => (v as num?)?.toDouble(),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    isRead: $checkedConvert('isRead', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$PriceDropNotificationToJson(
  PriceDropNotification instance,
) => <String, dynamic>{
  'id': instance.id,
  'priceAlertId': instance.priceAlertId,
  'listingId': instance.listingId,
  'listingTitle': instance.listingTitle,
  'listingImageUrl': ?instance.listingImageUrl,
  'oldPrice': instance.oldPrice,
  'newPrice': instance.newPrice,
  'dropPercentage': ?instance.dropPercentage,
  'createdAt': instance.createdAt.toIso8601String(),
  'isRead': instance.isRead,
};
