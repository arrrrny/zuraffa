// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Category', json, ($checkedConvert) {
      final val = Category(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String?),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$ProductCategoryEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': ?instance.description,
  'type': _$ProductCategoryEnumMap[instance.type]!,
};

const _$ProductCategoryEnumMap = {
  ProductCategory.marketplace: 'marketplace',
  ProductCategory.beauty: 'beauty',
  ProductCategory.menApparel: 'menApparel',
  ProductCategory.womenApparel: 'womenApparel',
  ProductCategory.homeImprovement: 'homeImprovement',
  ProductCategory.electronics: 'electronics',
  ProductCategory.baby: 'baby',
  ProductCategory.kids: 'kids',
  ProductCategory.grocery: 'grocery',
  ProductCategory.officeSupplies: 'officeSupplies',
  ProductCategory.other: 'other',
};
