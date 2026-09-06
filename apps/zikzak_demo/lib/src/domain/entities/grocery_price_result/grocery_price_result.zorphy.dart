// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_price_result.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GroceryPriceResult {
  GroceryPriceResult({
    required String this.storeName,
    String? this.storeLogoUrl,
    required double this.price,
    required String this.unit,
    double? this.distance,
    required bool this.isOnSale,
    double? this.originalPrice,
  });

  factory GroceryPriceResult.fromJson(Map<String, dynamic> json) =>
      _$GroceryPriceResultFromJson(json);

  final String storeName;

  final String? storeLogoUrl;

  final double price;

  final String unit;

  final double? distance;

  final bool isOnSale;

  final double? originalPrice;

  GroceryPriceResult copyWith({
    String? storeName,
    String? storeLogoUrl,
    double? price,
    String? unit,
    double? distance,
    bool? isOnSale,
    double? originalPrice,
  }) {
    return GroceryPriceResult(
      storeName: storeName ?? this.storeName,
      storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      distance: distance ?? this.distance,
      isOnSale: isOnSale ?? this.isOnSale,
      originalPrice: originalPrice ?? this.originalPrice,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GroceryPriceResult copyWithField<T>(
    Field<GroceryPriceResult, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'storeName':
        return copyWith(storeName: value as String);
      case 'storeLogoUrl':
        return copyWith(storeLogoUrl: value as String?);
      case 'price':
        return copyWith(price: value as double);
      case 'unit':
        return copyWith(unit: value as String);
      case 'distance':
        return copyWith(distance: value as double?);
      case 'isOnSale':
        return copyWith(isOnSale: value as bool);
      case 'originalPrice':
        return copyWith(originalPrice: value as double?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GroceryPriceResult has no settable field with this name',
        );
    }
  }

  GroceryPriceResult copyWithGroceryPriceResult({
    String? storeName,
    String? storeLogoUrl,
    double? price,
    String? unit,
    double? distance,
    bool? isOnSale,
    double? originalPrice,
  }) {
    return copyWith(
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      price: price,
      unit: unit,
      distance: distance,
      isOnSale: isOnSale,
      originalPrice: originalPrice,
    );
  }

  GroceryPriceResult patchWithGroceryPriceResult([
    GroceryPriceResultPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? GroceryPriceResultPatch();
    final _patchMap = _patcher.patchMap;
    return GroceryPriceResult(
      storeName: _patchMap.containsKey(GroceryPriceResult$.storeName)
          ? ((_patchMap[GroceryPriceResult$.storeName] is Function)
                    ? _patchMap[GroceryPriceResult$.storeName](this.storeName)
                    : (_patchMap[GroceryPriceResult$.storeName] is Patch)
                    ? _patchMap[GroceryPriceResult$.storeName].applyTo(
                        this.storeName,
                      )
                    : _patchMap[GroceryPriceResult$.storeName])
                as String
          : this.storeName,
      storeLogoUrl: _patchMap.containsKey(GroceryPriceResult$.storeLogoUrl)
          ? ((_patchMap[GroceryPriceResult$.storeLogoUrl] is Function)
                    ? _patchMap[GroceryPriceResult$.storeLogoUrl](
                        this.storeLogoUrl,
                      )
                    : (_patchMap[GroceryPriceResult$.storeLogoUrl] is Patch)
                    ? _patchMap[GroceryPriceResult$.storeLogoUrl].applyTo(
                        this.storeLogoUrl,
                      )
                    : _patchMap[GroceryPriceResult$.storeLogoUrl])
                as String?
          : this.storeLogoUrl,
      price: _patchMap.containsKey(GroceryPriceResult$.price)
          ? ((_patchMap[GroceryPriceResult$.price] is Function)
                    ? _patchMap[GroceryPriceResult$.price](this.price)
                    : (_patchMap[GroceryPriceResult$.price] is Patch)
                    ? _patchMap[GroceryPriceResult$.price].applyTo(this.price)
                    : _patchMap[GroceryPriceResult$.price])
                as double
          : this.price,
      unit: _patchMap.containsKey(GroceryPriceResult$.unit)
          ? ((_patchMap[GroceryPriceResult$.unit] is Function)
                    ? _patchMap[GroceryPriceResult$.unit](this.unit)
                    : (_patchMap[GroceryPriceResult$.unit] is Patch)
                    ? _patchMap[GroceryPriceResult$.unit].applyTo(this.unit)
                    : _patchMap[GroceryPriceResult$.unit])
                as String
          : this.unit,
      distance: _patchMap.containsKey(GroceryPriceResult$.distance)
          ? ((_patchMap[GroceryPriceResult$.distance] is Function)
                    ? _patchMap[GroceryPriceResult$.distance](this.distance)
                    : (_patchMap[GroceryPriceResult$.distance] is Patch)
                    ? _patchMap[GroceryPriceResult$.distance].applyTo(
                        this.distance,
                      )
                    : _patchMap[GroceryPriceResult$.distance])
                as double?
          : this.distance,
      isOnSale: _patchMap.containsKey(GroceryPriceResult$.isOnSale)
          ? ((_patchMap[GroceryPriceResult$.isOnSale] is Function)
                    ? _patchMap[GroceryPriceResult$.isOnSale](this.isOnSale)
                    : (_patchMap[GroceryPriceResult$.isOnSale] is Patch)
                    ? _patchMap[GroceryPriceResult$.isOnSale].applyTo(
                        this.isOnSale,
                      )
                    : _patchMap[GroceryPriceResult$.isOnSale])
                as bool
          : this.isOnSale,
      originalPrice: _patchMap.containsKey(GroceryPriceResult$.originalPrice)
          ? ((_patchMap[GroceryPriceResult$.originalPrice] is Function)
                    ? _patchMap[GroceryPriceResult$.originalPrice](
                        this.originalPrice,
                      )
                    : (_patchMap[GroceryPriceResult$.originalPrice] is Patch)
                    ? _patchMap[GroceryPriceResult$.originalPrice].applyTo(
                        this.originalPrice,
                      )
                    : _patchMap[GroceryPriceResult$.originalPrice])
                as double?
          : this.originalPrice,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryPriceResult &&
        storeName == other.storeName &&
        storeLogoUrl == other.storeLogoUrl &&
        price == other.price &&
        unit == other.unit &&
        distance == other.distance &&
        isOnSale == other.isOnSale &&
        originalPrice == other.originalPrice;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.storeName,
      this.storeLogoUrl,
      this.price,
      this.unit,
      this.distance,
      this.isOnSale,
      this.originalPrice,
    );
  }

  @override
  String toString() {
    return 'GroceryPriceResult(' +
        'storeName: ${storeName}' +
        ', ' +
        'storeLogoUrl: ${storeLogoUrl}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'unit: ${unit}' +
        ', ' +
        'distance: ${distance}' +
        ', ' +
        'isOnSale: ${isOnSale}' +
        ', ' +
        'originalPrice: ${originalPrice})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GroceryPriceResultToJson(this);
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

extension GroceryPriceResultPropertyHelpers on GroceryPriceResult {
  bool get hasStoreName {
    return this.storeName.isNotEmpty;
  }

  bool get noStoreName {
    return this.storeName.isEmpty;
  }

  bool get hasStoreLogoUrl {
    return this.storeLogoUrl?.isNotEmpty == true;
  }

  bool get noStoreLogoUrl {
    return this.storeLogoUrl?.isEmpty ?? true;
  }

  String get storeLogoUrlRequired {
    return this.storeLogoUrl ??
        (throw StateError('storeLogoUrl is required but was null'));
  }

  bool get hasUnit {
    return this.unit.isNotEmpty;
  }

  bool get noUnit {
    return this.unit.isEmpty;
  }

  bool get hasDistance {
    return this.distance != null;
  }

  bool get noDistance {
    return this.distance == null;
  }

  double get distanceRequired {
    return this.distance ??
        (throw StateError('distance is required but was null'));
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
}

extension GroceryPriceResultSerialization on GroceryPriceResult {
  Map<String, dynamic> toJson() {
    return _$GroceryPriceResultToJson(this);
  }
}

enum GroceryPriceResult$ {
  storeName,
  storeLogoUrl,
  price,
  unit,
  distance,
  isOnSale,
  originalPrice,
}

class GroceryPriceResultPatch
    extends PatchBase<GroceryPriceResult, GroceryPriceResult$> {
  GroceryPriceResult applyTo(GroceryPriceResult entity) {
    return entity.patchWithGroceryPriceResult(this);
  }

  GroceryPriceResultPatch withStoreName(String? value) {
    patchMap[GroceryPriceResult$.storeName] = value;
    return this;
  }

  GroceryPriceResultPatch withStoreLogoUrl(String? value) {
    patchMap[GroceryPriceResult$.storeLogoUrl] = value;
    return this;
  }

  GroceryPriceResultPatch withPrice(double? value) {
    patchMap[GroceryPriceResult$.price] = value;
    return this;
  }

  GroceryPriceResultPatch withUnit(String? value) {
    patchMap[GroceryPriceResult$.unit] = value;
    return this;
  }

  GroceryPriceResultPatch withDistance(double? value) {
    patchMap[GroceryPriceResult$.distance] = value;
    return this;
  }

  GroceryPriceResultPatch withIsOnSale(bool? value) {
    patchMap[GroceryPriceResult$.isOnSale] = value;
    return this;
  }

  GroceryPriceResultPatch withOriginalPrice(double? value) {
    patchMap[GroceryPriceResult$.originalPrice] = value;
    return this;
  }
}

/// Field descriptors for [GroceryPriceResult] query construction
abstract final class GroceryPriceResultFields {
  static const storeName = Field<GroceryPriceResult, String>(
    'storeName',
    _$storeName,
  );

  static const storeLogoUrl = Field<GroceryPriceResult, String?>(
    'storeLogoUrl',
    _$storeLogoUrl,
  );

  static const price = Field<GroceryPriceResult, double>('price', _$price);

  static const unit = Field<GroceryPriceResult, String>('unit', _$unit);

  static const distance = Field<GroceryPriceResult, double?>(
    'distance',
    _$distance,
  );

  static const isOnSale = Field<GroceryPriceResult, bool>(
    'isOnSale',
    _$isOnSale,
  );

  static const originalPrice = Field<GroceryPriceResult, double?>(
    'originalPrice',
    _$originalPrice,
  );

  static String _$storeName(GroceryPriceResult e) {
    return e.storeName;
  }

  static String? _$storeLogoUrl(GroceryPriceResult e) {
    return e.storeLogoUrl;
  }

  static double _$price(GroceryPriceResult e) {
    return e.price;
  }

  static String _$unit(GroceryPriceResult e) {
    return e.unit;
  }

  static double? _$distance(GroceryPriceResult e) {
    return e.distance;
  }

  static bool _$isOnSale(GroceryPriceResult e) {
    return e.isOnSale;
  }

  static double? _$originalPrice(GroceryPriceResult e) {
    return e.originalPrice;
  }
}

extension GroceryPriceResultCompareE on GroceryPriceResult {
  Map<String, dynamic> compareToGroceryPriceResult(GroceryPriceResult other) {
    final Map<String, dynamic> diff = {};

    if (storeName != other.storeName) {
      diff['storeName'] = () => other.storeName;
    }

    if (storeLogoUrl != other.storeLogoUrl) {
      diff['storeLogoUrl'] = () => other.storeLogoUrl;
    }

    if (price != other.price) {
      diff['price'] = () => other.price;
    }

    if (unit != other.unit) {
      diff['unit'] = () => other.unit;
    }

    if (distance != other.distance) {
      diff['distance'] = () => other.distance;
    }

    if (isOnSale != other.isOnSale) {
      diff['isOnSale'] = () => other.isOnSale;
    }

    if (originalPrice != other.originalPrice) {
      diff['originalPrice'] = () => other.originalPrice;
    }
    return diff;
  }
}
