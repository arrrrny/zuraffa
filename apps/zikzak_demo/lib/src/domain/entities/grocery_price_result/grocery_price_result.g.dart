// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_price_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroceryPriceResult _$GroceryPriceResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GroceryPriceResult', json, ($checkedConvert) {
      final val = GroceryPriceResult(
        storeName: $checkedConvert('storeName', (v) => v as String),
        storeLogoUrl: $checkedConvert('storeLogoUrl', (v) => v as String?),
        price: $checkedConvert('price', (v) => (v as num).toDouble()),
        unit: $checkedConvert('unit', (v) => v as String),
        distance: $checkedConvert('distance', (v) => (v as num?)?.toDouble()),
        isOnSale: $checkedConvert('isOnSale', (v) => v as bool),
        originalPrice: $checkedConvert(
          'originalPrice',
          (v) => (v as num?)?.toDouble(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GroceryPriceResultToJson(GroceryPriceResult instance) =>
    <String, dynamic>{
      'storeName': instance.storeName,
      'storeLogoUrl': ?instance.storeLogoUrl,
      'price': instance.price,
      'unit': instance.unit,
      'distance': ?instance.distance,
      'isOnSale': instance.isOnSale,
      'originalPrice': ?instance.originalPrice,
    };
