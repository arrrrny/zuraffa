// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Deal _$DealFromJson(Map<String, dynamic> json) => $checkedCreate('Deal', json, (
  $checkedConvert,
) {
  final val = Deal(
    id: $checkedConvert('id', (v) => v as String),
    listing: $checkedConvert(
      'listing',
      (v) => Listing.fromJson(v as Map<String, dynamic>),
    ),
    badges: $checkedConvert(
      'badges',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
    ),
    discountRate: $checkedConvert(
      'discountRate',
      (v) => (v as num?)?.toDouble(),
    ),
    likeCount: $checkedConvert('likeCount', (v) => (v as num).toInt()),
    dislikeCount: $checkedConvert('dislikeCount', (v) => (v as num).toInt()),
    shareCount: $checkedConvert('shareCount', (v) => (v as num).toInt()),
    manLikeCount: $checkedConvert('manLikeCount', (v) => (v as num).toInt()),
    womanLikeCount: $checkedConvert(
      'womanLikeCount',
      (v) => (v as num).toInt(),
    ),
    manDislikeCount: $checkedConvert(
      'manDislikeCount',
      (v) => (v as num).toInt(),
    ),
    womanDislikeCount: $checkedConvert(
      'womanDislikeCount',
      (v) => (v as num).toInt(),
    ),
    ratingScore: $checkedConvert('ratingScore', (v) => (v as num?)?.toDouble()),
    reviewCount: $checkedConvert('reviewCount', (v) => (v as num?)?.toInt()),
    aiReasoning: $checkedConvert('aiReasoning', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$DealToJson(Deal instance) => <String, dynamic>{
  'id': instance.id,
  'listing': instance.listing.toJson(),
  'badges': ?instance.badges,
  'discountRate': ?instance.discountRate,
  'likeCount': instance.likeCount,
  'dislikeCount': instance.dislikeCount,
  'shareCount': instance.shareCount,
  'manLikeCount': instance.manLikeCount,
  'womanLikeCount': instance.womanLikeCount,
  'manDislikeCount': instance.manDislikeCount,
  'womanDislikeCount': instance.womanDislikeCount,
  'ratingScore': ?instance.ratingScore,
  'reviewCount': ?instance.reviewCount,
  'aiReasoning': ?instance.aiReasoning,
};
