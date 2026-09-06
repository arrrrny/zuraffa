// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nearby_grocery_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NearbyGroceryStore _$NearbyGroceryStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NearbyGroceryStore', json, ($checkedConvert) {
      final val = NearbyGroceryStore(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        logoUrl: $checkedConvert('logoUrl', (v) => v as String?),
        distance: $checkedConvert('distance', (v) => (v as num).toDouble()),
        latitude: $checkedConvert('latitude', (v) => (v as num?)?.toDouble()),
        longitude: $checkedConvert('longitude', (v) => (v as num?)?.toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$NearbyGroceryStoreToJson(NearbyGroceryStore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'logoUrl': ?instance.logoUrl,
      'distance': instance.distance,
      'latitude': ?instance.latitude,
      'longitude': ?instance.longitude,
    };
