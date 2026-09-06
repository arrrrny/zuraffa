// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Subscription', json, ($checkedConvert) {
      final val = Subscription(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String),
        price: $checkedConvert('price', (v) => v as String),
        rawPrice: $checkedConvert('rawPrice', (v) => v as String),
        currencyCode: $checkedConvert('currencyCode', (v) => v as String),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$ProductTypeEnumMap, v),
        ),
        isPurchased: $checkedConvert('isPurchased', (v) => v as bool),
        error: $checkedConvert('error', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'price': instance.price,
      'rawPrice': instance.rawPrice,
      'currencyCode': instance.currencyCode,
      'type': _$ProductTypeEnumMap[instance.type]!,
      'isPurchased': instance.isPurchased,
      'error': ?instance.error,
    };

const _$ProductTypeEnumMap = {
  ProductType.consumable: 'consumable',
  ProductType.nonConsumable: 'nonConsumable',
  ProductType.autoRenewableSubscription: 'autoRenewableSubscription',
  ProductType.nonRenewingSubscription: 'nonRenewingSubscription',
};
