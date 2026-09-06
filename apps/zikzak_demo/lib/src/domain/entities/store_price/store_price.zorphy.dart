// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'store_price.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class StorePrice {
  StorePrice({
    required String this.depotId,
    required String this.depotName,
    required double this.price,
    String? this.unitPrice,
    double? this.unitPriceValue,
    required String this.marketName,
    required double this.percentage,
    required double this.latitude,
    required double this.longitude,
    String? this.indexTime,
    required bool this.isDiscounted,
    double? this.discountRatio,
    String? this.promotionText,
  });

  factory StorePrice.fromJson(Map<String, dynamic> json) =>
      _$StorePriceFromJson(json);

  final String depotId;

  final String depotName;

  final double price;

  final String? unitPrice;

  final double? unitPriceValue;

  final String marketName;

  final double percentage;

  final double latitude;

  final double longitude;

  final String? indexTime;

  final bool isDiscounted;

  final double? discountRatio;

  final String? promotionText;

  StorePrice copyWith({
    String? depotId,
    String? depotName,
    double? price,
    String? unitPrice,
    double? unitPriceValue,
    String? marketName,
    double? percentage,
    double? latitude,
    double? longitude,
    String? indexTime,
    bool? isDiscounted,
    double? discountRatio,
    String? promotionText,
  }) {
    return StorePrice(
      depotId: depotId ?? this.depotId,
      depotName: depotName ?? this.depotName,
      price: price ?? this.price,
      unitPrice: unitPrice ?? this.unitPrice,
      unitPriceValue: unitPriceValue ?? this.unitPriceValue,
      marketName: marketName ?? this.marketName,
      percentage: percentage ?? this.percentage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      indexTime: indexTime ?? this.indexTime,
      isDiscounted: isDiscounted ?? this.isDiscounted,
      discountRatio: discountRatio ?? this.discountRatio,
      promotionText: promotionText ?? this.promotionText,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  StorePrice copyWithField<T>(Field<StorePrice, T> field, T value) {
    switch (field.name) {
      case 'depotId':
        return copyWith(depotId: value as String);
      case 'depotName':
        return copyWith(depotName: value as String);
      case 'price':
        return copyWith(price: value as double);
      case 'unitPrice':
        return copyWith(unitPrice: value as String?);
      case 'unitPriceValue':
        return copyWith(unitPriceValue: value as double?);
      case 'marketName':
        return copyWith(marketName: value as String);
      case 'percentage':
        return copyWith(percentage: value as double);
      case 'latitude':
        return copyWith(latitude: value as double);
      case 'longitude':
        return copyWith(longitude: value as double);
      case 'indexTime':
        return copyWith(indexTime: value as String?);
      case 'isDiscounted':
        return copyWith(isDiscounted: value as bool);
      case 'discountRatio':
        return copyWith(discountRatio: value as double?);
      case 'promotionText':
        return copyWith(promotionText: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'StorePrice has no settable field with this name',
        );
    }
  }

  StorePrice copyWithStorePrice({
    String? depotId,
    String? depotName,
    double? price,
    String? unitPrice,
    double? unitPriceValue,
    String? marketName,
    double? percentage,
    double? latitude,
    double? longitude,
    String? indexTime,
    bool? isDiscounted,
    double? discountRatio,
    String? promotionText,
  }) {
    return copyWith(
      depotId: depotId,
      depotName: depotName,
      price: price,
      unitPrice: unitPrice,
      unitPriceValue: unitPriceValue,
      marketName: marketName,
      percentage: percentage,
      latitude: latitude,
      longitude: longitude,
      indexTime: indexTime,
      isDiscounted: isDiscounted,
      discountRatio: discountRatio,
      promotionText: promotionText,
    );
  }

  StorePrice patchWithStorePrice([StorePricePatch? patchInput]) {
    final _patcher = patchInput ?? StorePricePatch();
    final _patchMap = _patcher.patchMap;
    return StorePrice(
      depotId: _patchMap.containsKey(StorePrice$.depotId)
          ? ((_patchMap[StorePrice$.depotId] is Function)
                    ? _patchMap[StorePrice$.depotId](this.depotId)
                    : (_patchMap[StorePrice$.depotId] is Patch)
                    ? _patchMap[StorePrice$.depotId].applyTo(this.depotId)
                    : _patchMap[StorePrice$.depotId])
                as String
          : this.depotId,
      depotName: _patchMap.containsKey(StorePrice$.depotName)
          ? ((_patchMap[StorePrice$.depotName] is Function)
                    ? _patchMap[StorePrice$.depotName](this.depotName)
                    : (_patchMap[StorePrice$.depotName] is Patch)
                    ? _patchMap[StorePrice$.depotName].applyTo(this.depotName)
                    : _patchMap[StorePrice$.depotName])
                as String
          : this.depotName,
      price: _patchMap.containsKey(StorePrice$.price)
          ? ((_patchMap[StorePrice$.price] is Function)
                    ? _patchMap[StorePrice$.price](this.price)
                    : (_patchMap[StorePrice$.price] is Patch)
                    ? _patchMap[StorePrice$.price].applyTo(this.price)
                    : _patchMap[StorePrice$.price])
                as double
          : this.price,
      unitPrice: _patchMap.containsKey(StorePrice$.unitPrice)
          ? ((_patchMap[StorePrice$.unitPrice] is Function)
                    ? _patchMap[StorePrice$.unitPrice](this.unitPrice)
                    : (_patchMap[StorePrice$.unitPrice] is Patch)
                    ? _patchMap[StorePrice$.unitPrice].applyTo(this.unitPrice)
                    : _patchMap[StorePrice$.unitPrice])
                as String?
          : this.unitPrice,
      unitPriceValue: _patchMap.containsKey(StorePrice$.unitPriceValue)
          ? ((_patchMap[StorePrice$.unitPriceValue] is Function)
                    ? _patchMap[StorePrice$.unitPriceValue](this.unitPriceValue)
                    : (_patchMap[StorePrice$.unitPriceValue] is Patch)
                    ? _patchMap[StorePrice$.unitPriceValue].applyTo(
                        this.unitPriceValue,
                      )
                    : _patchMap[StorePrice$.unitPriceValue])
                as double?
          : this.unitPriceValue,
      marketName: _patchMap.containsKey(StorePrice$.marketName)
          ? ((_patchMap[StorePrice$.marketName] is Function)
                    ? _patchMap[StorePrice$.marketName](this.marketName)
                    : (_patchMap[StorePrice$.marketName] is Patch)
                    ? _patchMap[StorePrice$.marketName].applyTo(this.marketName)
                    : _patchMap[StorePrice$.marketName])
                as String
          : this.marketName,
      percentage: _patchMap.containsKey(StorePrice$.percentage)
          ? ((_patchMap[StorePrice$.percentage] is Function)
                    ? _patchMap[StorePrice$.percentage](this.percentage)
                    : (_patchMap[StorePrice$.percentage] is Patch)
                    ? _patchMap[StorePrice$.percentage].applyTo(this.percentage)
                    : _patchMap[StorePrice$.percentage])
                as double
          : this.percentage,
      latitude: _patchMap.containsKey(StorePrice$.latitude)
          ? ((_patchMap[StorePrice$.latitude] is Function)
                    ? _patchMap[StorePrice$.latitude](this.latitude)
                    : (_patchMap[StorePrice$.latitude] is Patch)
                    ? _patchMap[StorePrice$.latitude].applyTo(this.latitude)
                    : _patchMap[StorePrice$.latitude])
                as double
          : this.latitude,
      longitude: _patchMap.containsKey(StorePrice$.longitude)
          ? ((_patchMap[StorePrice$.longitude] is Function)
                    ? _patchMap[StorePrice$.longitude](this.longitude)
                    : (_patchMap[StorePrice$.longitude] is Patch)
                    ? _patchMap[StorePrice$.longitude].applyTo(this.longitude)
                    : _patchMap[StorePrice$.longitude])
                as double
          : this.longitude,
      indexTime: _patchMap.containsKey(StorePrice$.indexTime)
          ? ((_patchMap[StorePrice$.indexTime] is Function)
                    ? _patchMap[StorePrice$.indexTime](this.indexTime)
                    : (_patchMap[StorePrice$.indexTime] is Patch)
                    ? _patchMap[StorePrice$.indexTime].applyTo(this.indexTime)
                    : _patchMap[StorePrice$.indexTime])
                as String?
          : this.indexTime,
      isDiscounted: _patchMap.containsKey(StorePrice$.isDiscounted)
          ? ((_patchMap[StorePrice$.isDiscounted] is Function)
                    ? _patchMap[StorePrice$.isDiscounted](this.isDiscounted)
                    : (_patchMap[StorePrice$.isDiscounted] is Patch)
                    ? _patchMap[StorePrice$.isDiscounted].applyTo(
                        this.isDiscounted,
                      )
                    : _patchMap[StorePrice$.isDiscounted])
                as bool
          : this.isDiscounted,
      discountRatio: _patchMap.containsKey(StorePrice$.discountRatio)
          ? ((_patchMap[StorePrice$.discountRatio] is Function)
                    ? _patchMap[StorePrice$.discountRatio](this.discountRatio)
                    : (_patchMap[StorePrice$.discountRatio] is Patch)
                    ? _patchMap[StorePrice$.discountRatio].applyTo(
                        this.discountRatio,
                      )
                    : _patchMap[StorePrice$.discountRatio])
                as double?
          : this.discountRatio,
      promotionText: _patchMap.containsKey(StorePrice$.promotionText)
          ? ((_patchMap[StorePrice$.promotionText] is Function)
                    ? _patchMap[StorePrice$.promotionText](this.promotionText)
                    : (_patchMap[StorePrice$.promotionText] is Patch)
                    ? _patchMap[StorePrice$.promotionText].applyTo(
                        this.promotionText,
                      )
                    : _patchMap[StorePrice$.promotionText])
                as String?
          : this.promotionText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorePrice &&
        depotId == other.depotId &&
        depotName == other.depotName &&
        price == other.price &&
        unitPrice == other.unitPrice &&
        unitPriceValue == other.unitPriceValue &&
        marketName == other.marketName &&
        percentage == other.percentage &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        indexTime == other.indexTime &&
        isDiscounted == other.isDiscounted &&
        discountRatio == other.discountRatio &&
        promotionText == other.promotionText;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.depotId,
      this.depotName,
      this.price,
      this.unitPrice,
      this.unitPriceValue,
      this.marketName,
      this.percentage,
      this.latitude,
      this.longitude,
      this.indexTime,
      this.isDiscounted,
      this.discountRatio,
      this.promotionText,
    );
  }

  @override
  String toString() {
    return 'StorePrice(' +
        'depotId: ${depotId}' +
        ', ' +
        'depotName: ${depotName}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'unitPrice: ${unitPrice}' +
        ', ' +
        'unitPriceValue: ${unitPriceValue}' +
        ', ' +
        'marketName: ${marketName}' +
        ', ' +
        'percentage: ${percentage}' +
        ', ' +
        'latitude: ${latitude}' +
        ', ' +
        'longitude: ${longitude}' +
        ', ' +
        'indexTime: ${indexTime}' +
        ', ' +
        'isDiscounted: ${isDiscounted}' +
        ', ' +
        'discountRatio: ${discountRatio}' +
        ', ' +
        'promotionText: ${promotionText})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$StorePriceToJson(this);
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

extension StorePricePropertyHelpers on StorePrice {
  bool get hasDepotId {
    return this.depotId.isNotEmpty;
  }

  bool get noDepotId {
    return this.depotId.isEmpty;
  }

  bool get hasDepotName {
    return this.depotName.isNotEmpty;
  }

  bool get noDepotName {
    return this.depotName.isEmpty;
  }

  bool get hasUnitPrice {
    return this.unitPrice?.isNotEmpty == true;
  }

  bool get noUnitPrice {
    return this.unitPrice?.isEmpty ?? true;
  }

  String get unitPriceRequired {
    return this.unitPrice ??
        (throw StateError('unitPrice is required but was null'));
  }

  bool get hasUnitPriceValue {
    return this.unitPriceValue != null;
  }

  bool get noUnitPriceValue {
    return this.unitPriceValue == null;
  }

  double get unitPriceValueRequired {
    return this.unitPriceValue ??
        (throw StateError('unitPriceValue is required but was null'));
  }

  bool get hasMarketName {
    return this.marketName.isNotEmpty;
  }

  bool get noMarketName {
    return this.marketName.isEmpty;
  }

  bool get hasIndexTime {
    return this.indexTime?.isNotEmpty == true;
  }

  bool get noIndexTime {
    return this.indexTime?.isEmpty ?? true;
  }

  String get indexTimeRequired {
    return this.indexTime ??
        (throw StateError('indexTime is required but was null'));
  }

  bool get hasDiscountRatio {
    return this.discountRatio != null;
  }

  bool get noDiscountRatio {
    return this.discountRatio == null;
  }

  double get discountRatioRequired {
    return this.discountRatio ??
        (throw StateError('discountRatio is required but was null'));
  }

  bool get hasPromotionText {
    return this.promotionText?.isNotEmpty == true;
  }

  bool get noPromotionText {
    return this.promotionText?.isEmpty ?? true;
  }

  String get promotionTextRequired {
    return this.promotionText ??
        (throw StateError('promotionText is required but was null'));
  }
}

extension StorePriceSerialization on StorePrice {
  Map<String, dynamic> toJson() {
    return _$StorePriceToJson(this);
  }
}

enum StorePrice$ {
  depotId,
  depotName,
  price,
  unitPrice,
  unitPriceValue,
  marketName,
  percentage,
  latitude,
  longitude,
  indexTime,
  isDiscounted,
  discountRatio,
  promotionText,
}

class StorePricePatch extends PatchBase<StorePrice, StorePrice$> {
  StorePrice applyTo(StorePrice entity) {
    return entity.patchWithStorePrice(this);
  }

  StorePricePatch withDepotId(String? value) {
    patchMap[StorePrice$.depotId] = value;
    return this;
  }

  StorePricePatch withDepotName(String? value) {
    patchMap[StorePrice$.depotName] = value;
    return this;
  }

  StorePricePatch withPrice(double? value) {
    patchMap[StorePrice$.price] = value;
    return this;
  }

  StorePricePatch withUnitPrice(String? value) {
    patchMap[StorePrice$.unitPrice] = value;
    return this;
  }

  StorePricePatch withUnitPriceValue(double? value) {
    patchMap[StorePrice$.unitPriceValue] = value;
    return this;
  }

  StorePricePatch withMarketName(String? value) {
    patchMap[StorePrice$.marketName] = value;
    return this;
  }

  StorePricePatch withPercentage(double? value) {
    patchMap[StorePrice$.percentage] = value;
    return this;
  }

  StorePricePatch withLatitude(double? value) {
    patchMap[StorePrice$.latitude] = value;
    return this;
  }

  StorePricePatch withLongitude(double? value) {
    patchMap[StorePrice$.longitude] = value;
    return this;
  }

  StorePricePatch withIndexTime(String? value) {
    patchMap[StorePrice$.indexTime] = value;
    return this;
  }

  StorePricePatch withIsDiscounted(bool? value) {
    patchMap[StorePrice$.isDiscounted] = value;
    return this;
  }

  StorePricePatch withDiscountRatio(double? value) {
    patchMap[StorePrice$.discountRatio] = value;
    return this;
  }

  StorePricePatch withPromotionText(String? value) {
    patchMap[StorePrice$.promotionText] = value;
    return this;
  }
}

/// Field descriptors for [StorePrice] query construction
abstract final class StorePriceFields {
  static const depotId = Field<StorePrice, String>('depotId', _$depotId);

  static const depotName = Field<StorePrice, String>('depotName', _$depotName);

  static const price = Field<StorePrice, double>('price', _$price);

  static const unitPrice = Field<StorePrice, String?>('unitPrice', _$unitPrice);

  static const unitPriceValue = Field<StorePrice, double?>(
    'unitPriceValue',
    _$unitPriceValue,
  );

  static const marketName = Field<StorePrice, String>(
    'marketName',
    _$marketName,
  );

  static const percentage = Field<StorePrice, double>(
    'percentage',
    _$percentage,
  );

  static const latitude = Field<StorePrice, double>('latitude', _$latitude);

  static const longitude = Field<StorePrice, double>('longitude', _$longitude);

  static const indexTime = Field<StorePrice, String?>('indexTime', _$indexTime);

  static const isDiscounted = Field<StorePrice, bool>(
    'isDiscounted',
    _$isDiscounted,
  );

  static const discountRatio = Field<StorePrice, double?>(
    'discountRatio',
    _$discountRatio,
  );

  static const promotionText = Field<StorePrice, String?>(
    'promotionText',
    _$promotionText,
  );

  static String _$depotId(StorePrice e) {
    return e.depotId;
  }

  static String _$depotName(StorePrice e) {
    return e.depotName;
  }

  static double _$price(StorePrice e) {
    return e.price;
  }

  static String? _$unitPrice(StorePrice e) {
    return e.unitPrice;
  }

  static double? _$unitPriceValue(StorePrice e) {
    return e.unitPriceValue;
  }

  static String _$marketName(StorePrice e) {
    return e.marketName;
  }

  static double _$percentage(StorePrice e) {
    return e.percentage;
  }

  static double _$latitude(StorePrice e) {
    return e.latitude;
  }

  static double _$longitude(StorePrice e) {
    return e.longitude;
  }

  static String? _$indexTime(StorePrice e) {
    return e.indexTime;
  }

  static bool _$isDiscounted(StorePrice e) {
    return e.isDiscounted;
  }

  static double? _$discountRatio(StorePrice e) {
    return e.discountRatio;
  }

  static String? _$promotionText(StorePrice e) {
    return e.promotionText;
  }
}

extension StorePriceCompareE on StorePrice {
  Map<String, dynamic> compareToStorePrice(StorePrice other) {
    final Map<String, dynamic> diff = {};

    if (depotId != other.depotId) {
      diff['depotId'] = () => other.depotId;
    }

    if (depotName != other.depotName) {
      diff['depotName'] = () => other.depotName;
    }

    if (price != other.price) {
      diff['price'] = () => other.price;
    }

    if (unitPrice != other.unitPrice) {
      diff['unitPrice'] = () => other.unitPrice;
    }

    if (unitPriceValue != other.unitPriceValue) {
      diff['unitPriceValue'] = () => other.unitPriceValue;
    }

    if (marketName != other.marketName) {
      diff['marketName'] = () => other.marketName;
    }

    if (percentage != other.percentage) {
      diff['percentage'] = () => other.percentage;
    }

    if (latitude != other.latitude) {
      diff['latitude'] = () => other.latitude;
    }

    if (longitude != other.longitude) {
      diff['longitude'] = () => other.longitude;
    }

    if (indexTime != other.indexTime) {
      diff['indexTime'] = () => other.indexTime;
    }

    if (isDiscounted != other.isDiscounted) {
      diff['isDiscounted'] = () => other.isDiscounted;
    }

    if (discountRatio != other.discountRatio) {
      diff['discountRatio'] = () => other.discountRatio;
    }

    if (promotionText != other.promotionText) {
      diff['promotionText'] = () => other.promotionText;
    }
    return diff;
  }
}
