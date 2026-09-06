// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_sub_variety.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrocerySubVariety _$GrocerySubVarietyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GrocerySubVariety', json, ($checkedConvert) {
      final val = GrocerySubVariety(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        localizedName: $checkedConvert(
          'localizedName',
          (v) => (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GrocerySubVarietyToJson(GrocerySubVariety instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'localizedName': ?instance.localizedName,
    };
