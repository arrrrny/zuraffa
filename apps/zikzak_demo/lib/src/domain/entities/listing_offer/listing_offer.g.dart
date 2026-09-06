// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListingOffer _$ListingOfferFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListingOffer', json, ($checkedConvert) {
  final val = ListingOffer(
    id: $checkedConvert('id', (v) => v as String?),
    code: $checkedConvert('code', (v) => v as String?),
    price: $checkedConvert('price', (v) => (v as num?)?.toDouble()),
    originalPrice: $checkedConvert(
      'originalPrice',
      (v) => (v as num?)?.toDouble(),
    ),
    unitPrice: $checkedConvert('unitPrice', (v) => (v as num?)?.toDouble()),
    unitPriceText: $checkedConvert('unitPriceText', (v) => v as String?),
    url: $checkedConvert('url', (v) => v as String?),
    website: $checkedConvert('website', (v) => v as String?),
    seller: $checkedConvert('seller', (v) => v as String?),
    sellerId: $checkedConvert('sellerId', (v) => v as String?),
    title: $checkedConvert('title', (v) => v as String?),
    sellerScore: $checkedConvert('sellerScore', (v) => (v as num?)?.toDouble()),
    availability: $checkedConvert('availability', (v) => v as String?),
    shippingCost: $checkedConvert(
      'shippingCost',
      (v) => (v as num?)?.toDouble(),
    ),
    shippingInfo: $checkedConvert('shippingInfo', (v) => v as String?),
    sellerIcon: $checkedConvert('sellerIcon', (v) => v as String?),
    badges: $checkedConvert(
      'badges',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
    ),
    brand: $checkedConvert('brand', (v) => v as String?),
    sku: $checkedConvert('sku', (v) => v as String?),
    imageUrl: $checkedConvert('imageUrl', (v) => v as String?),
    images: $checkedConvert(
      'images',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
    ),
    ratingScore: $checkedConvert('ratingScore', (v) => (v as num?)?.toDouble()),
    reviewCount: $checkedConvert('reviewCount', (v) => (v as num?)?.toInt()),
    productId: $checkedConvert('productId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ListingOfferToJson(ListingOffer instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'code': ?instance.code,
      'price': ?instance.price,
      'originalPrice': ?instance.originalPrice,
      'unitPrice': ?instance.unitPrice,
      'unitPriceText': ?instance.unitPriceText,
      'url': ?instance.url,
      'website': ?instance.website,
      'seller': ?instance.seller,
      'sellerId': ?instance.sellerId,
      'title': ?instance.title,
      'sellerScore': ?instance.sellerScore,
      'availability': ?instance.availability,
      'shippingCost': ?instance.shippingCost,
      'shippingInfo': ?instance.shippingInfo,
      'sellerIcon': ?instance.sellerIcon,
      'badges': ?instance.badges,
      'brand': ?instance.brand,
      'sku': ?instance.sku,
      'imageUrl': ?instance.imageUrl,
      'images': ?instance.images,
      'ratingScore': ?instance.ratingScore,
      'reviewCount': ?instance.reviewCount,
      'productId': ?instance.productId,
    };
