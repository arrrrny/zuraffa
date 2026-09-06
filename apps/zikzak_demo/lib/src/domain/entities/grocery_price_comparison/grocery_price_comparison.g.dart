// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_price_comparison.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroceryPriceComparison _$GroceryPriceComparisonFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GroceryPriceComparison', json, ($checkedConvert) {
  final val = GroceryPriceComparison(
    itemName: $checkedConvert('itemName', (v) => v as String),
    itemId: $checkedConvert('itemId', (v) => v as String?),
    selectedSubVariety: $checkedConvert(
      'selectedSubVariety',
      (v) => v as String?,
    ),
    prices: $checkedConvert(
      'prices',
      (v) => (v as List<dynamic>)
          .map((e) => GroceryPriceResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    detectionSource: $checkedConvert('detectionSource', (v) => v as String),
    detectionConfidence: $checkedConvert(
      'detectionConfidence',
      (v) => (v as num).toDouble(),
    ),
  );
  return val;
});

Map<String, dynamic> _$GroceryPriceComparisonToJson(
  GroceryPriceComparison instance,
) => <String, dynamic>{
  'itemName': instance.itemName,
  'itemId': ?instance.itemId,
  'selectedSubVariety': ?instance.selectedSubVariety,
  'prices': instance.prices.map((e) => e.toJson()).toList(),
  'detectionSource': instance.detectionSource,
  'detectionConfidence': instance.detectionConfidence,
};
