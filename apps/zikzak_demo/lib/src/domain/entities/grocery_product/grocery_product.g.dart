// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroceryProduct _$GroceryProductFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GroceryProduct', json, ($checkedConvert) {
      final val = GroceryProduct(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        brand: $checkedConvert('brand', (v) => v as String?),
        imageUrl: $checkedConvert('imageUrl', (v) => v as String?),
        volumeOrWeight: $checkedConvert('volumeOrWeight', (v) => v as String?),
        categories: $checkedConvert(
          'categories',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        mainCategory: $checkedConvert('mainCategory', (v) => v as String),
        menuCategory: $checkedConvert('menuCategory', (v) => v as String?),
        storePrices: $checkedConvert(
          'storePrices',
          (v) => (v as List<dynamic>)
              .map((e) => StorePrice.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GroceryProductToJson(GroceryProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'brand': ?instance.brand,
      'imageUrl': ?instance.imageUrl,
      'volumeOrWeight': ?instance.volumeOrWeight,
      'categories': instance.categories,
      'mainCategory': instance.mainCategory,
      'menuCategory': ?instance.menuCategory,
      'storePrices': instance.storePrices.map((e) => e.toJson()).toList(),
    };
