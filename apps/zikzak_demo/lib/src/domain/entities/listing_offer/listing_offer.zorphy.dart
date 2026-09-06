// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'listing_offer.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ListingOffer {
  ListingOffer({
    String? this.id,
    String? this.code,
    double? this.price,
    double? this.originalPrice,
    double? this.unitPrice,
    String? this.unitPriceText,
    String? this.url,
    String? this.website,
    String? this.seller,
    String? this.sellerId,
    String? this.title,
    double? this.sellerScore,
    String? this.availability,
    double? this.shippingCost,
    String? this.shippingInfo,
    String? this.sellerIcon,
    List<String>? this.badges,
    String? this.brand,
    String? this.sku,
    String? this.imageUrl,
    List<String>? this.images,
    double? this.ratingScore,
    int? this.reviewCount,
    String? this.productId,
  });

  factory ListingOffer.fromJson(Map<String, dynamic> json) =>
      _$ListingOfferFromJson(json);

  final String? id;

  final String? code;

  final double? price;

  final double? originalPrice;

  final double? unitPrice;

  final String? unitPriceText;

  final String? url;

  final String? website;

  final String? seller;

  final String? sellerId;

  final String? title;

  final double? sellerScore;

  final String? availability;

  final double? shippingCost;

  final String? shippingInfo;

  final String? sellerIcon;

  final List<String>? badges;

  final String? brand;

  final String? sku;

  final String? imageUrl;

  final List<String>? images;

  final double? ratingScore;

  final int? reviewCount;

  final String? productId;

  ListingOffer copyWith({
    String? id,
    String? code,
    double? price,
    double? originalPrice,
    double? unitPrice,
    String? unitPriceText,
    String? url,
    String? website,
    String? seller,
    String? sellerId,
    String? title,
    double? sellerScore,
    String? availability,
    double? shippingCost,
    String? shippingInfo,
    String? sellerIcon,
    List<String>? badges,
    String? brand,
    String? sku,
    String? imageUrl,
    List<String>? images,
    double? ratingScore,
    int? reviewCount,
    String? productId,
  }) {
    return ListingOffer(
      id: id ?? this.id,
      code: code ?? this.code,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      unitPriceText: unitPriceText ?? this.unitPriceText,
      url: url ?? this.url,
      website: website ?? this.website,
      seller: seller ?? this.seller,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      sellerScore: sellerScore ?? this.sellerScore,
      availability: availability ?? this.availability,
      shippingCost: shippingCost ?? this.shippingCost,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      sellerIcon: sellerIcon ?? this.sellerIcon,
      badges: badges ?? this.badges,
      brand: brand ?? this.brand,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      ratingScore: ratingScore ?? this.ratingScore,
      reviewCount: reviewCount ?? this.reviewCount,
      productId: productId ?? this.productId,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ListingOffer copyWithField<T>(Field<ListingOffer, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'code':
        return copyWith(code: value as String?);
      case 'price':
        return copyWith(price: value as double?);
      case 'originalPrice':
        return copyWith(originalPrice: value as double?);
      case 'unitPrice':
        return copyWith(unitPrice: value as double?);
      case 'unitPriceText':
        return copyWith(unitPriceText: value as String?);
      case 'url':
        return copyWith(url: value as String?);
      case 'website':
        return copyWith(website: value as String?);
      case 'seller':
        return copyWith(seller: value as String?);
      case 'sellerId':
        return copyWith(sellerId: value as String?);
      case 'title':
        return copyWith(title: value as String?);
      case 'sellerScore':
        return copyWith(sellerScore: value as double?);
      case 'availability':
        return copyWith(availability: value as String?);
      case 'shippingCost':
        return copyWith(shippingCost: value as double?);
      case 'shippingInfo':
        return copyWith(shippingInfo: value as String?);
      case 'sellerIcon':
        return copyWith(sellerIcon: value as String?);
      case 'badges':
        return copyWith(badges: value as List<String>?);
      case 'brand':
        return copyWith(brand: value as String?);
      case 'sku':
        return copyWith(sku: value as String?);
      case 'imageUrl':
        return copyWith(imageUrl: value as String?);
      case 'images':
        return copyWith(images: value as List<String>?);
      case 'ratingScore':
        return copyWith(ratingScore: value as double?);
      case 'reviewCount':
        return copyWith(reviewCount: value as int?);
      case 'productId':
        return copyWith(productId: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ListingOffer has no settable field with this name',
        );
    }
  }

  ListingOffer copyWithListingOffer({
    String? id,
    String? code,
    double? price,
    double? originalPrice,
    double? unitPrice,
    String? unitPriceText,
    String? url,
    String? website,
    String? seller,
    String? sellerId,
    String? title,
    double? sellerScore,
    String? availability,
    double? shippingCost,
    String? shippingInfo,
    String? sellerIcon,
    List<String>? badges,
    String? brand,
    String? sku,
    String? imageUrl,
    List<String>? images,
    double? ratingScore,
    int? reviewCount,
    String? productId,
  }) {
    return copyWith(
      id: id,
      code: code,
      price: price,
      originalPrice: originalPrice,
      unitPrice: unitPrice,
      unitPriceText: unitPriceText,
      url: url,
      website: website,
      seller: seller,
      sellerId: sellerId,
      title: title,
      sellerScore: sellerScore,
      availability: availability,
      shippingCost: shippingCost,
      shippingInfo: shippingInfo,
      sellerIcon: sellerIcon,
      badges: badges,
      brand: brand,
      sku: sku,
      imageUrl: imageUrl,
      images: images,
      ratingScore: ratingScore,
      reviewCount: reviewCount,
      productId: productId,
    );
  }

  ListingOffer patchWithListingOffer([ListingOfferPatch? patchInput]) {
    final _patcher = patchInput ?? ListingOfferPatch();
    final _patchMap = _patcher.patchMap;
    return ListingOffer(
      id: _patchMap.containsKey(ListingOffer$.id)
          ? ((_patchMap[ListingOffer$.id] is Function)
                    ? _patchMap[ListingOffer$.id](this.id)
                    : (_patchMap[ListingOffer$.id] is Patch)
                    ? _patchMap[ListingOffer$.id].applyTo(this.id)
                    : _patchMap[ListingOffer$.id])
                as String?
          : this.id,
      code: _patchMap.containsKey(ListingOffer$.code)
          ? ((_patchMap[ListingOffer$.code] is Function)
                    ? _patchMap[ListingOffer$.code](this.code)
                    : (_patchMap[ListingOffer$.code] is Patch)
                    ? _patchMap[ListingOffer$.code].applyTo(this.code)
                    : _patchMap[ListingOffer$.code])
                as String?
          : this.code,
      price: _patchMap.containsKey(ListingOffer$.price)
          ? ((_patchMap[ListingOffer$.price] is Function)
                    ? _patchMap[ListingOffer$.price](this.price)
                    : (_patchMap[ListingOffer$.price] is Patch)
                    ? _patchMap[ListingOffer$.price].applyTo(this.price)
                    : _patchMap[ListingOffer$.price])
                as double?
          : this.price,
      originalPrice: _patchMap.containsKey(ListingOffer$.originalPrice)
          ? ((_patchMap[ListingOffer$.originalPrice] is Function)
                    ? _patchMap[ListingOffer$.originalPrice](this.originalPrice)
                    : (_patchMap[ListingOffer$.originalPrice] is Patch)
                    ? _patchMap[ListingOffer$.originalPrice].applyTo(
                        this.originalPrice,
                      )
                    : _patchMap[ListingOffer$.originalPrice])
                as double?
          : this.originalPrice,
      unitPrice: _patchMap.containsKey(ListingOffer$.unitPrice)
          ? ((_patchMap[ListingOffer$.unitPrice] is Function)
                    ? _patchMap[ListingOffer$.unitPrice](this.unitPrice)
                    : (_patchMap[ListingOffer$.unitPrice] is Patch)
                    ? _patchMap[ListingOffer$.unitPrice].applyTo(this.unitPrice)
                    : _patchMap[ListingOffer$.unitPrice])
                as double?
          : this.unitPrice,
      unitPriceText: _patchMap.containsKey(ListingOffer$.unitPriceText)
          ? ((_patchMap[ListingOffer$.unitPriceText] is Function)
                    ? _patchMap[ListingOffer$.unitPriceText](this.unitPriceText)
                    : (_patchMap[ListingOffer$.unitPriceText] is Patch)
                    ? _patchMap[ListingOffer$.unitPriceText].applyTo(
                        this.unitPriceText,
                      )
                    : _patchMap[ListingOffer$.unitPriceText])
                as String?
          : this.unitPriceText,
      url: _patchMap.containsKey(ListingOffer$.url)
          ? ((_patchMap[ListingOffer$.url] is Function)
                    ? _patchMap[ListingOffer$.url](this.url)
                    : (_patchMap[ListingOffer$.url] is Patch)
                    ? _patchMap[ListingOffer$.url].applyTo(this.url)
                    : _patchMap[ListingOffer$.url])
                as String?
          : this.url,
      website: _patchMap.containsKey(ListingOffer$.website)
          ? ((_patchMap[ListingOffer$.website] is Function)
                    ? _patchMap[ListingOffer$.website](this.website)
                    : (_patchMap[ListingOffer$.website] is Patch)
                    ? _patchMap[ListingOffer$.website].applyTo(this.website)
                    : _patchMap[ListingOffer$.website])
                as String?
          : this.website,
      seller: _patchMap.containsKey(ListingOffer$.seller)
          ? ((_patchMap[ListingOffer$.seller] is Function)
                    ? _patchMap[ListingOffer$.seller](this.seller)
                    : (_patchMap[ListingOffer$.seller] is Patch)
                    ? _patchMap[ListingOffer$.seller].applyTo(this.seller)
                    : _patchMap[ListingOffer$.seller])
                as String?
          : this.seller,
      sellerId: _patchMap.containsKey(ListingOffer$.sellerId)
          ? ((_patchMap[ListingOffer$.sellerId] is Function)
                    ? _patchMap[ListingOffer$.sellerId](this.sellerId)
                    : (_patchMap[ListingOffer$.sellerId] is Patch)
                    ? _patchMap[ListingOffer$.sellerId].applyTo(this.sellerId)
                    : _patchMap[ListingOffer$.sellerId])
                as String?
          : this.sellerId,
      title: _patchMap.containsKey(ListingOffer$.title)
          ? ((_patchMap[ListingOffer$.title] is Function)
                    ? _patchMap[ListingOffer$.title](this.title)
                    : (_patchMap[ListingOffer$.title] is Patch)
                    ? _patchMap[ListingOffer$.title].applyTo(this.title)
                    : _patchMap[ListingOffer$.title])
                as String?
          : this.title,
      sellerScore: _patchMap.containsKey(ListingOffer$.sellerScore)
          ? ((_patchMap[ListingOffer$.sellerScore] is Function)
                    ? _patchMap[ListingOffer$.sellerScore](this.sellerScore)
                    : (_patchMap[ListingOffer$.sellerScore] is Patch)
                    ? _patchMap[ListingOffer$.sellerScore].applyTo(
                        this.sellerScore,
                      )
                    : _patchMap[ListingOffer$.sellerScore])
                as double?
          : this.sellerScore,
      availability: _patchMap.containsKey(ListingOffer$.availability)
          ? ((_patchMap[ListingOffer$.availability] is Function)
                    ? _patchMap[ListingOffer$.availability](this.availability)
                    : (_patchMap[ListingOffer$.availability] is Patch)
                    ? _patchMap[ListingOffer$.availability].applyTo(
                        this.availability,
                      )
                    : _patchMap[ListingOffer$.availability])
                as String?
          : this.availability,
      shippingCost: _patchMap.containsKey(ListingOffer$.shippingCost)
          ? ((_patchMap[ListingOffer$.shippingCost] is Function)
                    ? _patchMap[ListingOffer$.shippingCost](this.shippingCost)
                    : (_patchMap[ListingOffer$.shippingCost] is Patch)
                    ? _patchMap[ListingOffer$.shippingCost].applyTo(
                        this.shippingCost,
                      )
                    : _patchMap[ListingOffer$.shippingCost])
                as double?
          : this.shippingCost,
      shippingInfo: _patchMap.containsKey(ListingOffer$.shippingInfo)
          ? ((_patchMap[ListingOffer$.shippingInfo] is Function)
                    ? _patchMap[ListingOffer$.shippingInfo](this.shippingInfo)
                    : (_patchMap[ListingOffer$.shippingInfo] is Patch)
                    ? _patchMap[ListingOffer$.shippingInfo].applyTo(
                        this.shippingInfo,
                      )
                    : _patchMap[ListingOffer$.shippingInfo])
                as String?
          : this.shippingInfo,
      sellerIcon: _patchMap.containsKey(ListingOffer$.sellerIcon)
          ? ((_patchMap[ListingOffer$.sellerIcon] is Function)
                    ? _patchMap[ListingOffer$.sellerIcon](this.sellerIcon)
                    : (_patchMap[ListingOffer$.sellerIcon] is Patch)
                    ? _patchMap[ListingOffer$.sellerIcon].applyTo(
                        this.sellerIcon,
                      )
                    : _patchMap[ListingOffer$.sellerIcon])
                as String?
          : this.sellerIcon,
      badges: _patchMap.containsKey(ListingOffer$.badges)
          ? ((_patchMap[ListingOffer$.badges] is Function)
                    ? _patchMap[ListingOffer$.badges](this.badges)
                    : (_patchMap[ListingOffer$.badges] is Patch)
                    ? _patchMap[ListingOffer$.badges].applyTo(this.badges)
                    : _patchMap[ListingOffer$.badges])
                as List<String>?
          : this.badges,
      brand: _patchMap.containsKey(ListingOffer$.brand)
          ? ((_patchMap[ListingOffer$.brand] is Function)
                    ? _patchMap[ListingOffer$.brand](this.brand)
                    : (_patchMap[ListingOffer$.brand] is Patch)
                    ? _patchMap[ListingOffer$.brand].applyTo(this.brand)
                    : _patchMap[ListingOffer$.brand])
                as String?
          : this.brand,
      sku: _patchMap.containsKey(ListingOffer$.sku)
          ? ((_patchMap[ListingOffer$.sku] is Function)
                    ? _patchMap[ListingOffer$.sku](this.sku)
                    : (_patchMap[ListingOffer$.sku] is Patch)
                    ? _patchMap[ListingOffer$.sku].applyTo(this.sku)
                    : _patchMap[ListingOffer$.sku])
                as String?
          : this.sku,
      imageUrl: _patchMap.containsKey(ListingOffer$.imageUrl)
          ? ((_patchMap[ListingOffer$.imageUrl] is Function)
                    ? _patchMap[ListingOffer$.imageUrl](this.imageUrl)
                    : (_patchMap[ListingOffer$.imageUrl] is Patch)
                    ? _patchMap[ListingOffer$.imageUrl].applyTo(this.imageUrl)
                    : _patchMap[ListingOffer$.imageUrl])
                as String?
          : this.imageUrl,
      images: _patchMap.containsKey(ListingOffer$.images)
          ? ((_patchMap[ListingOffer$.images] is Function)
                    ? _patchMap[ListingOffer$.images](this.images)
                    : (_patchMap[ListingOffer$.images] is Patch)
                    ? _patchMap[ListingOffer$.images].applyTo(this.images)
                    : _patchMap[ListingOffer$.images])
                as List<String>?
          : this.images,
      ratingScore: _patchMap.containsKey(ListingOffer$.ratingScore)
          ? ((_patchMap[ListingOffer$.ratingScore] is Function)
                    ? _patchMap[ListingOffer$.ratingScore](this.ratingScore)
                    : (_patchMap[ListingOffer$.ratingScore] is Patch)
                    ? _patchMap[ListingOffer$.ratingScore].applyTo(
                        this.ratingScore,
                      )
                    : _patchMap[ListingOffer$.ratingScore])
                as double?
          : this.ratingScore,
      reviewCount: _patchMap.containsKey(ListingOffer$.reviewCount)
          ? ((_patchMap[ListingOffer$.reviewCount] is Function)
                    ? _patchMap[ListingOffer$.reviewCount](this.reviewCount)
                    : (_patchMap[ListingOffer$.reviewCount] is Patch)
                    ? _patchMap[ListingOffer$.reviewCount].applyTo(
                        this.reviewCount,
                      )
                    : _patchMap[ListingOffer$.reviewCount])
                as int?
          : this.reviewCount,
      productId: _patchMap.containsKey(ListingOffer$.productId)
          ? ((_patchMap[ListingOffer$.productId] is Function)
                    ? _patchMap[ListingOffer$.productId](this.productId)
                    : (_patchMap[ListingOffer$.productId] is Patch)
                    ? _patchMap[ListingOffer$.productId].applyTo(this.productId)
                    : _patchMap[ListingOffer$.productId])
                as String?
          : this.productId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListingOffer &&
        id == other.id &&
        code == other.code &&
        price == other.price &&
        originalPrice == other.originalPrice &&
        unitPrice == other.unitPrice &&
        unitPriceText == other.unitPriceText &&
        url == other.url &&
        website == other.website &&
        seller == other.seller &&
        sellerId == other.sellerId &&
        title == other.title &&
        sellerScore == other.sellerScore &&
        availability == other.availability &&
        shippingCost == other.shippingCost &&
        shippingInfo == other.shippingInfo &&
        sellerIcon == other.sellerIcon &&
        badges == other.badges &&
        brand == other.brand &&
        sku == other.sku &&
        imageUrl == other.imageUrl &&
        images == other.images &&
        ratingScore == other.ratingScore &&
        reviewCount == other.reviewCount &&
        productId == other.productId;
  }

  @override
  int get hashCode {
    return Object.hash(
          this.id,
          this.code,
          this.price,
          this.originalPrice,
          this.unitPrice,
          this.unitPriceText,
          this.url,
          this.website,
          this.seller,
          this.sellerId,
          this.title,
          this.sellerScore,
          this.availability,
          this.shippingCost,
          this.shippingInfo,
          this.sellerIcon,
          this.badges,
          this.brand,
          this.sku,
          this.imageUrl,
        ) ^
        Object.hash(
          this.images,
          this.ratingScore,
          this.reviewCount,
          this.productId,
        );
  }

  @override
  String toString() {
    return 'ListingOffer(' +
        'id: ${id}' +
        ', ' +
        'code: ${code}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'originalPrice: ${originalPrice}' +
        ', ' +
        'unitPrice: ${unitPrice}' +
        ', ' +
        'unitPriceText: ${unitPriceText}' +
        ', ' +
        'url: ${url}' +
        ', ' +
        'website: ${website}' +
        ', ' +
        'seller: ${seller}' +
        ', ' +
        'sellerId: ${sellerId}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'sellerScore: ${sellerScore}' +
        ', ' +
        'availability: ${availability}' +
        ', ' +
        'shippingCost: ${shippingCost}' +
        ', ' +
        'shippingInfo: ${shippingInfo}' +
        ', ' +
        'sellerIcon: ${sellerIcon}' +
        ', ' +
        'badges: ${badges}' +
        ', ' +
        'brand: ${brand}' +
        ', ' +
        'sku: ${sku}' +
        ', ' +
        'imageUrl: ${imageUrl}' +
        ', ' +
        'images: ${images}' +
        ', ' +
        'ratingScore: ${ratingScore}' +
        ', ' +
        'reviewCount: ${reviewCount}' +
        ', ' +
        'productId: ${productId})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ListingOfferToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension ListingOfferPropertyHelpers on ListingOffer {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasCode {
    return this.code?.isNotEmpty == true;
  }

  bool get noCode {
    return this.code?.isEmpty ?? true;
  }

  String get codeRequired {
    return this.code ?? (throw StateError('code is required but was null'));
  }

  bool get hasPrice {
    return this.price != null;
  }

  bool get noPrice {
    return this.price == null;
  }

  double get priceRequired {
    return this.price ?? (throw StateError('price is required but was null'));
  }

  bool get hasOriginalPrice {
    return this.originalPrice != null;
  }

  bool get noOriginalPrice {
    return this.originalPrice == null;
  }

  double get originalPriceRequired {
    return this.originalPrice ??
        (throw StateError('originalPrice is required but was null'));
  }

  bool get hasUnitPrice {
    return this.unitPrice != null;
  }

  bool get noUnitPrice {
    return this.unitPrice == null;
  }

  double get unitPriceRequired {
    return this.unitPrice ??
        (throw StateError('unitPrice is required but was null'));
  }

  bool get hasUnitPriceText {
    return this.unitPriceText?.isNotEmpty == true;
  }

  bool get noUnitPriceText {
    return this.unitPriceText?.isEmpty ?? true;
  }

  String get unitPriceTextRequired {
    return this.unitPriceText ??
        (throw StateError('unitPriceText is required but was null'));
  }

  bool get hasUrl {
    return this.url?.isNotEmpty == true;
  }

  bool get noUrl {
    return this.url?.isEmpty ?? true;
  }

  String get urlRequired {
    return this.url ?? (throw StateError('url is required but was null'));
  }

  bool get hasWebsite {
    return this.website?.isNotEmpty == true;
  }

  bool get noWebsite {
    return this.website?.isEmpty ?? true;
  }

  String get websiteRequired {
    return this.website ??
        (throw StateError('website is required but was null'));
  }

  bool get hasSeller {
    return this.seller?.isNotEmpty == true;
  }

  bool get noSeller {
    return this.seller?.isEmpty ?? true;
  }

  String get sellerRequired {
    return this.seller ?? (throw StateError('seller is required but was null'));
  }

  bool get hasSellerId {
    return this.sellerId?.isNotEmpty == true;
  }

  bool get noSellerId {
    return this.sellerId?.isEmpty ?? true;
  }

  String get sellerIdRequired {
    return this.sellerId ??
        (throw StateError('sellerId is required but was null'));
  }

  bool get hasTitle {
    return this.title?.isNotEmpty == true;
  }

  bool get noTitle {
    return this.title?.isEmpty ?? true;
  }

  String get titleRequired {
    return this.title ?? (throw StateError('title is required but was null'));
  }

  bool get hasSellerScore {
    return this.sellerScore != null;
  }

  bool get noSellerScore {
    return this.sellerScore == null;
  }

  double get sellerScoreRequired {
    return this.sellerScore ??
        (throw StateError('sellerScore is required but was null'));
  }

  bool get hasAvailability {
    return this.availability?.isNotEmpty == true;
  }

  bool get noAvailability {
    return this.availability?.isEmpty ?? true;
  }

  String get availabilityRequired {
    return this.availability ??
        (throw StateError('availability is required but was null'));
  }

  bool get hasShippingCost {
    return this.shippingCost != null;
  }

  bool get noShippingCost {
    return this.shippingCost == null;
  }

  double get shippingCostRequired {
    return this.shippingCost ??
        (throw StateError('shippingCost is required but was null'));
  }

  bool get hasShippingInfo {
    return this.shippingInfo?.isNotEmpty == true;
  }

  bool get noShippingInfo {
    return this.shippingInfo?.isEmpty ?? true;
  }

  String get shippingInfoRequired {
    return this.shippingInfo ??
        (throw StateError('shippingInfo is required but was null'));
  }

  bool get hasSellerIcon {
    return this.sellerIcon?.isNotEmpty == true;
  }

  bool get noSellerIcon {
    return this.sellerIcon?.isEmpty ?? true;
  }

  String get sellerIconRequired {
    return this.sellerIcon ??
        (throw StateError('sellerIcon is required but was null'));
  }

  List<String> get badgesRequired {
    return this.badges ?? (throw StateError('badges is required but was null'));
  }

  bool get hasBadges {
    return this.badges?.isNotEmpty ?? false;
  }

  bool get noBadges {
    return this.badges?.isEmpty ?? true;
  }

  bool get hasBrand {
    return this.brand?.isNotEmpty == true;
  }

  bool get noBrand {
    return this.brand?.isEmpty ?? true;
  }

  String get brandRequired {
    return this.brand ?? (throw StateError('brand is required but was null'));
  }

  bool get hasSku {
    return this.sku?.isNotEmpty == true;
  }

  bool get noSku {
    return this.sku?.isEmpty ?? true;
  }

  String get skuRequired {
    return this.sku ?? (throw StateError('sku is required but was null'));
  }

  bool get hasImageUrl {
    return this.imageUrl?.isNotEmpty == true;
  }

  bool get noImageUrl {
    return this.imageUrl?.isEmpty ?? true;
  }

  String get imageUrlRequired {
    return this.imageUrl ??
        (throw StateError('imageUrl is required but was null'));
  }

  List<String> get imagesRequired {
    return this.images ?? (throw StateError('images is required but was null'));
  }

  bool get hasImages {
    return this.images?.isNotEmpty ?? false;
  }

  bool get noImages {
    return this.images?.isEmpty ?? true;
  }

  bool get hasRatingScore {
    return this.ratingScore != null;
  }

  bool get noRatingScore {
    return this.ratingScore == null;
  }

  double get ratingScoreRequired {
    return this.ratingScore ??
        (throw StateError('ratingScore is required but was null'));
  }

  bool get hasReviewCount {
    return this.reviewCount != null;
  }

  bool get noReviewCount {
    return this.reviewCount == null;
  }

  int get reviewCountRequired {
    return this.reviewCount ??
        (throw StateError('reviewCount is required but was null'));
  }

  bool get hasProductId {
    return this.productId?.isNotEmpty == true;
  }

  bool get noProductId {
    return this.productId?.isEmpty ?? true;
  }

  String get productIdRequired {
    return this.productId ??
        (throw StateError('productId is required but was null'));
  }
}

extension ListingOfferSerialization on ListingOffer {
  Map<String, dynamic> toJson() {
    return _$ListingOfferToJson(this);
  }
}

enum ListingOffer$ {
  id,
  code,
  price,
  originalPrice,
  unitPrice,
  unitPriceText,
  url,
  website,
  seller,
  sellerId,
  title,
  sellerScore,
  availability,
  shippingCost,
  shippingInfo,
  sellerIcon,
  badges,
  brand,
  sku,
  imageUrl,
  images,
  ratingScore,
  reviewCount,
  productId,
}

class ListingOfferPatch extends PatchBase<ListingOffer, ListingOffer$> {
  ListingOffer applyTo(ListingOffer entity) {
    return entity.patchWithListingOffer(this);
  }

  ListingOfferPatch withId(String? value) {
    patchMap[ListingOffer$.id] = value;
    return this;
  }

  ListingOfferPatch withCode(String? value) {
    patchMap[ListingOffer$.code] = value;
    return this;
  }

  ListingOfferPatch withPrice(double? value) {
    patchMap[ListingOffer$.price] = value;
    return this;
  }

  ListingOfferPatch withOriginalPrice(double? value) {
    patchMap[ListingOffer$.originalPrice] = value;
    return this;
  }

  ListingOfferPatch withUnitPrice(double? value) {
    patchMap[ListingOffer$.unitPrice] = value;
    return this;
  }

  ListingOfferPatch withUnitPriceText(String? value) {
    patchMap[ListingOffer$.unitPriceText] = value;
    return this;
  }

  ListingOfferPatch withUrl(String? value) {
    patchMap[ListingOffer$.url] = value;
    return this;
  }

  ListingOfferPatch withWebsite(String? value) {
    patchMap[ListingOffer$.website] = value;
    return this;
  }

  ListingOfferPatch withSeller(String? value) {
    patchMap[ListingOffer$.seller] = value;
    return this;
  }

  ListingOfferPatch withSellerId(String? value) {
    patchMap[ListingOffer$.sellerId] = value;
    return this;
  }

  ListingOfferPatch withTitle(String? value) {
    patchMap[ListingOffer$.title] = value;
    return this;
  }

  ListingOfferPatch withSellerScore(double? value) {
    patchMap[ListingOffer$.sellerScore] = value;
    return this;
  }

  ListingOfferPatch withAvailability(String? value) {
    patchMap[ListingOffer$.availability] = value;
    return this;
  }

  ListingOfferPatch withShippingCost(double? value) {
    patchMap[ListingOffer$.shippingCost] = value;
    return this;
  }

  ListingOfferPatch withShippingInfo(String? value) {
    patchMap[ListingOffer$.shippingInfo] = value;
    return this;
  }

  ListingOfferPatch withSellerIcon(String? value) {
    patchMap[ListingOffer$.sellerIcon] = value;
    return this;
  }

  ListingOfferPatch withBadges(List<String>? value) {
    patchMap[ListingOffer$.badges] = value;
    return this;
  }

  ListingOfferPatch withBrand(String? value) {
    patchMap[ListingOffer$.brand] = value;
    return this;
  }

  ListingOfferPatch withSku(String? value) {
    patchMap[ListingOffer$.sku] = value;
    return this;
  }

  ListingOfferPatch withImageUrl(String? value) {
    patchMap[ListingOffer$.imageUrl] = value;
    return this;
  }

  ListingOfferPatch withImages(List<String>? value) {
    patchMap[ListingOffer$.images] = value;
    return this;
  }

  ListingOfferPatch withRatingScore(double? value) {
    patchMap[ListingOffer$.ratingScore] = value;
    return this;
  }

  ListingOfferPatch withReviewCount(int? value) {
    patchMap[ListingOffer$.reviewCount] = value;
    return this;
  }

  ListingOfferPatch withProductId(String? value) {
    patchMap[ListingOffer$.productId] = value;
    return this;
  }
}

/// Field descriptors for [ListingOffer] query construction
abstract final class ListingOfferFields {
  static const id = Field<ListingOffer, String?>('id', _$id);

  static const code = Field<ListingOffer, String?>('code', _$code);

  static const price = Field<ListingOffer, double?>('price', _$price);

  static const originalPrice = Field<ListingOffer, double?>(
    'originalPrice',
    _$originalPrice,
  );

  static const unitPrice = Field<ListingOffer, double?>(
    'unitPrice',
    _$unitPrice,
  );

  static const unitPriceText = Field<ListingOffer, String?>(
    'unitPriceText',
    _$unitPriceText,
  );

  static const url = Field<ListingOffer, String?>('url', _$url);

  static const website = Field<ListingOffer, String?>('website', _$website);

  static const seller = Field<ListingOffer, String?>('seller', _$seller);

  static const sellerId = Field<ListingOffer, String?>('sellerId', _$sellerId);

  static const title = Field<ListingOffer, String?>('title', _$title);

  static const sellerScore = Field<ListingOffer, double?>(
    'sellerScore',
    _$sellerScore,
  );

  static const availability = Field<ListingOffer, String?>(
    'availability',
    _$availability,
  );

  static const shippingCost = Field<ListingOffer, double?>(
    'shippingCost',
    _$shippingCost,
  );

  static const shippingInfo = Field<ListingOffer, String?>(
    'shippingInfo',
    _$shippingInfo,
  );

  static const sellerIcon = Field<ListingOffer, String?>(
    'sellerIcon',
    _$sellerIcon,
  );

  static const badges = Field<ListingOffer, List<String>?>('badges', _$badges);

  static const brand = Field<ListingOffer, String?>('brand', _$brand);

  static const sku = Field<ListingOffer, String?>('sku', _$sku);

  static const imageUrl = Field<ListingOffer, String?>('imageUrl', _$imageUrl);

  static const images = Field<ListingOffer, List<String>?>('images', _$images);

  static const ratingScore = Field<ListingOffer, double?>(
    'ratingScore',
    _$ratingScore,
  );

  static const reviewCount = Field<ListingOffer, int?>(
    'reviewCount',
    _$reviewCount,
  );

  static const productId = Field<ListingOffer, String?>(
    'productId',
    _$productId,
  );

  static String? _$id(ListingOffer e) {
    return e.id;
  }

  static String? _$code(ListingOffer e) {
    return e.code;
  }

  static double? _$price(ListingOffer e) {
    return e.price;
  }

  static double? _$originalPrice(ListingOffer e) {
    return e.originalPrice;
  }

  static double? _$unitPrice(ListingOffer e) {
    return e.unitPrice;
  }

  static String? _$unitPriceText(ListingOffer e) {
    return e.unitPriceText;
  }

  static String? _$url(ListingOffer e) {
    return e.url;
  }

  static String? _$website(ListingOffer e) {
    return e.website;
  }

  static String? _$seller(ListingOffer e) {
    return e.seller;
  }

  static String? _$sellerId(ListingOffer e) {
    return e.sellerId;
  }

  static String? _$title(ListingOffer e) {
    return e.title;
  }

  static double? _$sellerScore(ListingOffer e) {
    return e.sellerScore;
  }

  static String? _$availability(ListingOffer e) {
    return e.availability;
  }

  static double? _$shippingCost(ListingOffer e) {
    return e.shippingCost;
  }

  static String? _$shippingInfo(ListingOffer e) {
    return e.shippingInfo;
  }

  static String? _$sellerIcon(ListingOffer e) {
    return e.sellerIcon;
  }

  static List<String>? _$badges(ListingOffer e) {
    return e.badges;
  }

  static String? _$brand(ListingOffer e) {
    return e.brand;
  }

  static String? _$sku(ListingOffer e) {
    return e.sku;
  }

  static String? _$imageUrl(ListingOffer e) {
    return e.imageUrl;
  }

  static List<String>? _$images(ListingOffer e) {
    return e.images;
  }

  static double? _$ratingScore(ListingOffer e) {
    return e.ratingScore;
  }

  static int? _$reviewCount(ListingOffer e) {
    return e.reviewCount;
  }

  static String? _$productId(ListingOffer e) {
    return e.productId;
  }
}

extension ListingOfferCompareE on ListingOffer {
  Map<String, dynamic> compareToListingOffer(ListingOffer other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (code != other.code) {
      diff['code'] = () => other.code;
    }

    if (price != other.price) {
      diff['price'] = () => other.price;
    }

    if (originalPrice != other.originalPrice) {
      diff['originalPrice'] = () => other.originalPrice;
    }

    if (unitPrice != other.unitPrice) {
      diff['unitPrice'] = () => other.unitPrice;
    }

    if (unitPriceText != other.unitPriceText) {
      diff['unitPriceText'] = () => other.unitPriceText;
    }

    if (url != other.url) {
      diff['url'] = () => other.url;
    }

    if (website != other.website) {
      diff['website'] = () => other.website;
    }

    if (seller != other.seller) {
      diff['seller'] = () => other.seller;
    }

    if (sellerId != other.sellerId) {
      diff['sellerId'] = () => other.sellerId;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (sellerScore != other.sellerScore) {
      diff['sellerScore'] = () => other.sellerScore;
    }

    if (availability != other.availability) {
      diff['availability'] = () => other.availability;
    }

    if (shippingCost != other.shippingCost) {
      diff['shippingCost'] = () => other.shippingCost;
    }

    if (shippingInfo != other.shippingInfo) {
      diff['shippingInfo'] = () => other.shippingInfo;
    }

    if (sellerIcon != other.sellerIcon) {
      diff['sellerIcon'] = () => other.sellerIcon;
    }

    if (badges != other.badges) {
      diff['badges'] = () => other.badges;
    }

    if (brand != other.brand) {
      diff['brand'] = () => other.brand;
    }

    if (sku != other.sku) {
      diff['sku'] = () => other.sku;
    }

    if (imageUrl != other.imageUrl) {
      diff['imageUrl'] = () => other.imageUrl;
    }

    if (images != other.images) {
      diff['images'] = () => other.images;
    }

    if (ratingScore != other.ratingScore) {
      diff['ratingScore'] = () => other.ratingScore;
    }

    if (reviewCount != other.reviewCount) {
      diff['reviewCount'] = () => other.reviewCount;
    }

    if (productId != other.productId) {
      diff['productId'] = () => other.productId;
    }
    return diff;
  }
}
