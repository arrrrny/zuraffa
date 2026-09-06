// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StorePrice _$StorePriceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('StorePrice', json, ($checkedConvert) {
      final val = StorePrice(
        depotId: $checkedConvert('depotId', (v) => v as String),
        depotName: $checkedConvert('depotName', (v) => v as String),
        price: $checkedConvert('price', (v) => (v as num).toDouble()),
        unitPrice: $checkedConvert('unitPrice', (v) => v as String?),
        unitPriceValue: $checkedConvert(
          'unitPriceValue',
          (v) => (v as num?)?.toDouble(),
        ),
        marketName: $checkedConvert('marketName', (v) => v as String),
        percentage: $checkedConvert('percentage', (v) => (v as num).toDouble()),
        latitude: $checkedConvert('latitude', (v) => (v as num).toDouble()),
        longitude: $checkedConvert('longitude', (v) => (v as num).toDouble()),
        indexTime: $checkedConvert('indexTime', (v) => v as String?),
        isDiscounted: $checkedConvert('isDiscounted', (v) => v as bool),
        discountRatio: $checkedConvert(
          'discountRatio',
          (v) => (v as num?)?.toDouble(),
        ),
        promotionText: $checkedConvert('promotionText', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$StorePriceToJson(StorePrice instance) =>
    <String, dynamic>{
      'depotId': instance.depotId,
      'depotName': instance.depotName,
      'price': instance.price,
      'unitPrice': ?instance.unitPrice,
      'unitPriceValue': ?instance.unitPriceValue,
      'marketName': instance.marketName,
      'percentage': instance.percentage,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'indexTime': ?instance.indexTime,
      'isDiscounted': instance.isDiscounted,
      'discountRatio': ?instance.discountRatio,
      'promotionText': ?instance.promotionText,
    };
