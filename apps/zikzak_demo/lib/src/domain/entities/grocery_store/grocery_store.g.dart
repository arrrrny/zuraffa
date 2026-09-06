// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroceryStore _$GroceryStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GroceryStore', json, ($checkedConvert) {
      final val = GroceryStore(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        marketName: $checkedConvert('marketName', (v) => v as String),
        latitude: $checkedConvert('latitude', (v) => (v as num).toDouble()),
        longitude: $checkedConvert('longitude', (v) => (v as num).toDouble()),
        distance: $checkedConvert('distance', (v) => (v as num).toDouble()),
        isSelected: $checkedConvert('isSelected', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$GroceryStoreToJson(GroceryStore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'marketName': instance.marketName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'distance': instance.distance,
      'isSelected': instance.isSelected,
    };
