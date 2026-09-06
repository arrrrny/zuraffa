// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceAlert _$PriceAlertFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PriceAlert', json, ($checkedConvert) {
  final val = PriceAlert(
    id: $checkedConvert('id', (v) => v as String),
    listingId: $checkedConvert('listingId', (v) => v as String),
    listingTitle: $checkedConvert('listingTitle', (v) => v as String?),
    listingImageUrl: $checkedConvert('listingImageUrl', (v) => v as String?),
    targetPrice: $checkedConvert('targetPrice', (v) => (v as num).toDouble()),
    currentPrice: $checkedConvert('currentPrice', (v) => (v as num).toDouble()),
    type: $checkedConvert('type', (v) => $enumDecode(_$FeedbackTypeEnumMap, v)),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    notifiedAt: $checkedConvert(
      'notifiedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    isActive: $checkedConvert('isActive', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$PriceAlertToJson(PriceAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'listingId': instance.listingId,
      'listingTitle': ?instance.listingTitle,
      'listingImageUrl': ?instance.listingImageUrl,
      'targetPrice': instance.targetPrice,
      'currentPrice': instance.currentPrice,
      'type': _$FeedbackTypeEnumMap[instance.type]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'notifiedAt': ?instance.notifiedAt?.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$FeedbackTypeEnumMap = {
  FeedbackType.error: 'error',
  FeedbackType.suggestion: 'suggestion',
  FeedbackType.thanks: 'thanks',
};
