// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Listing _$ListingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Listing', json, ($checkedConvert) {
      final val = Listing(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        offers: $checkedConvert(
          'offers',
          (v) => (v as List<dynamic>?)
              ?.map((e) => ListingOffer.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        similarListings: $checkedConvert(
          'similarListings',
          (v) => (v as List<dynamic>?)
              ?.map((e) => Listing.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        variations: $checkedConvert(
          'variations',
          (v) => (v as List<dynamic>?)
              ?.map((e) => Listing.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        hasGoogleShoppingMatch: $checkedConvert(
          'hasGoogleShoppingMatch',
          (v) => v as bool?,
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        groupId: $checkedConvert('groupId', (v) => v as String?),
        reviewSummary: $checkedConvert('reviewSummary', (v) => v as String?),
        enableAskZikZak: $checkedConvert('enableAskZikZak', (v) => v as bool),
        colorName: $checkedConvert('colorName', (v) => v as String?),
        thumbnailUrl: $checkedConvert('thumbnailUrl', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ListingToJson(Listing instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'offers': ?instance.offers?.map((e) => e.toJson()).toList(),
  'similarListings': ?instance.similarListings?.map((e) => e.toJson()).toList(),
  'variations': ?instance.variations?.map((e) => e.toJson()).toList(),
  'hasGoogleShoppingMatch': ?instance.hasGoogleShoppingMatch,
  'createdAt': ?instance.createdAt?.toIso8601String(),
  'updatedAt': ?instance.updatedAt?.toIso8601String(),
  'groupId': ?instance.groupId,
  'reviewSummary': ?instance.reviewSummary,
  'enableAskZikZak': instance.enableAskZikZak,
  'colorName': ?instance.colorName,
  'thumbnailUrl': ?instance.thumbnailUrl,
};
