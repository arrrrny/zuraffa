// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroceryItem _$GroceryItemFromJson(Map<String, dynamic> json) => $checkedCreate(
  'GroceryItem',
  json,
  ($checkedConvert) {
    final val = GroceryItem(
      id: $checkedConvert('id', (v) => v as String),
      canonicalName: $checkedConvert('canonicalName', (v) => v as String),
      category: $checkedConvert('category', (v) => v as String),
      detectionLabels: $checkedConvert(
        'detectionLabels',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      localizedName: $checkedConvert(
        'localizedName',
        (v) => Map<String, String>.from(v as Map),
      ),
      subVarieties: $checkedConvert(
        'subVarieties',
        (v) => (v as List<dynamic>?)
            ?.map((e) => GrocerySubVariety.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$GroceryItemToJson(GroceryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'canonicalName': instance.canonicalName,
      'category': instance.category,
      'detectionLabels': instance.detectionLabels,
      'localizedName': instance.localizedName,
      'subVarieties': ?instance.subVarieties?.map((e) => e.toJson()).toList(),
    };
