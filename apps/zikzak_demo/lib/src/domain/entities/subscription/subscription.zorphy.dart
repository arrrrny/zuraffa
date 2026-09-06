// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'subscription.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Subscription {
  Subscription({
    required String this.id,
    required String this.title,
    required String this.description,
    required String this.price,
    required String this.rawPrice,
    required String this.currencyCode,
    required ProductType this.type,
    required bool this.isPurchased,
    String? this.error,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  final String id;

  final String title;

  final String description;

  final String price;

  final String rawPrice;

  final String currencyCode;

  final ProductType type;

  final bool isPurchased;

  final String? error;

  Subscription copyWith({
    String? id,
    String? title,
    String? description,
    String? price,
    String? rawPrice,
    String? currencyCode,
    ProductType? type,
    bool? isPurchased,
    String? error,
  }) {
    return Subscription(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      rawPrice: rawPrice ?? this.rawPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      type: type ?? this.type,
      isPurchased: isPurchased ?? this.isPurchased,
      error: error ?? this.error,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Subscription copyWithField<T>(Field<Subscription, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'description':
        return copyWith(description: value as String);
      case 'price':
        return copyWith(price: value as String);
      case 'rawPrice':
        return copyWith(rawPrice: value as String);
      case 'currencyCode':
        return copyWith(currencyCode: value as String);
      case 'type':
        return copyWith(type: value as ProductType);
      case 'isPurchased':
        return copyWith(isPurchased: value as bool);
      case 'error':
        return copyWith(error: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Subscription has no settable field with this name',
        );
    }
  }

  Subscription copyWithSubscription({
    String? id,
    String? title,
    String? description,
    String? price,
    String? rawPrice,
    String? currencyCode,
    ProductType? type,
    bool? isPurchased,
    String? error,
  }) {
    return copyWith(
      id: id,
      title: title,
      description: description,
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
      type: type,
      isPurchased: isPurchased,
      error: error,
    );
  }

  Subscription patchWithSubscription([SubscriptionPatch? patchInput]) {
    final _patcher = patchInput ?? SubscriptionPatch();
    final _patchMap = _patcher.patchMap;
    return Subscription(
      id: _patchMap.containsKey(Subscription$.id)
          ? ((_patchMap[Subscription$.id] is Function)
                    ? _patchMap[Subscription$.id](this.id)
                    : (_patchMap[Subscription$.id] is Patch)
                    ? _patchMap[Subscription$.id].applyTo(this.id)
                    : _patchMap[Subscription$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(Subscription$.title)
          ? ((_patchMap[Subscription$.title] is Function)
                    ? _patchMap[Subscription$.title](this.title)
                    : (_patchMap[Subscription$.title] is Patch)
                    ? _patchMap[Subscription$.title].applyTo(this.title)
                    : _patchMap[Subscription$.title])
                as String
          : this.title,
      description: _patchMap.containsKey(Subscription$.description)
          ? ((_patchMap[Subscription$.description] is Function)
                    ? _patchMap[Subscription$.description](this.description)
                    : (_patchMap[Subscription$.description] is Patch)
                    ? _patchMap[Subscription$.description].applyTo(
                        this.description,
                      )
                    : _patchMap[Subscription$.description])
                as String
          : this.description,
      price: _patchMap.containsKey(Subscription$.price)
          ? ((_patchMap[Subscription$.price] is Function)
                    ? _patchMap[Subscription$.price](this.price)
                    : (_patchMap[Subscription$.price] is Patch)
                    ? _patchMap[Subscription$.price].applyTo(this.price)
                    : _patchMap[Subscription$.price])
                as String
          : this.price,
      rawPrice: _patchMap.containsKey(Subscription$.rawPrice)
          ? ((_patchMap[Subscription$.rawPrice] is Function)
                    ? _patchMap[Subscription$.rawPrice](this.rawPrice)
                    : (_patchMap[Subscription$.rawPrice] is Patch)
                    ? _patchMap[Subscription$.rawPrice].applyTo(this.rawPrice)
                    : _patchMap[Subscription$.rawPrice])
                as String
          : this.rawPrice,
      currencyCode: _patchMap.containsKey(Subscription$.currencyCode)
          ? ((_patchMap[Subscription$.currencyCode] is Function)
                    ? _patchMap[Subscription$.currencyCode](this.currencyCode)
                    : (_patchMap[Subscription$.currencyCode] is Patch)
                    ? _patchMap[Subscription$.currencyCode].applyTo(
                        this.currencyCode,
                      )
                    : _patchMap[Subscription$.currencyCode])
                as String
          : this.currencyCode,
      type: _patchMap.containsKey(Subscription$.type)
          ? ((_patchMap[Subscription$.type] is Function)
                    ? _patchMap[Subscription$.type](this.type)
                    : (_patchMap[Subscription$.type] is Patch)
                    ? _patchMap[Subscription$.type].applyTo(this.type)
                    : _patchMap[Subscription$.type])
                as ProductType
          : this.type,
      isPurchased: _patchMap.containsKey(Subscription$.isPurchased)
          ? ((_patchMap[Subscription$.isPurchased] is Function)
                    ? _patchMap[Subscription$.isPurchased](this.isPurchased)
                    : (_patchMap[Subscription$.isPurchased] is Patch)
                    ? _patchMap[Subscription$.isPurchased].applyTo(
                        this.isPurchased,
                      )
                    : _patchMap[Subscription$.isPurchased])
                as bool
          : this.isPurchased,
      error: _patchMap.containsKey(Subscription$.error)
          ? ((_patchMap[Subscription$.error] is Function)
                    ? _patchMap[Subscription$.error](this.error)
                    : (_patchMap[Subscription$.error] is Patch)
                    ? _patchMap[Subscription$.error].applyTo(this.error)
                    : _patchMap[Subscription$.error])
                as String?
          : this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        id == other.id &&
        title == other.title &&
        description == other.description &&
        price == other.price &&
        rawPrice == other.rawPrice &&
        currencyCode == other.currencyCode &&
        type == other.type &&
        isPurchased == other.isPurchased &&
        error == other.error;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.description,
      this.price,
      this.rawPrice,
      this.currencyCode,
      this.type,
      this.isPurchased,
      this.error,
    );
  }

  @override
  String toString() {
    return 'Subscription(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'rawPrice: ${rawPrice}' +
        ', ' +
        'currencyCode: ${currencyCode}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'isPurchased: ${isPurchased}' +
        ', ' +
        'error: ${error})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$SubscriptionToJson(this);
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

extension SubscriptionPropertyHelpers on Subscription {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasTitle {
    return this.title.isNotEmpty;
  }

  bool get noTitle {
    return this.title.isEmpty;
  }

  bool get hasDescription {
    return this.description.isNotEmpty;
  }

  bool get noDescription {
    return this.description.isEmpty;
  }

  bool get hasPrice {
    return this.price.isNotEmpty;
  }

  bool get noPrice {
    return this.price.isEmpty;
  }

  bool get hasRawPrice {
    return this.rawPrice.isNotEmpty;
  }

  bool get noRawPrice {
    return this.rawPrice.isEmpty;
  }

  bool get hasCurrencyCode {
    return this.currencyCode.isNotEmpty;
  }

  bool get noCurrencyCode {
    return this.currencyCode.isEmpty;
  }

  bool get isTypeConsumable {
    return this.type == ProductType.consumable;
  }

  bool get isTypeNonConsumable {
    return this.type == ProductType.nonConsumable;
  }

  bool get isTypeAutoRenewableSubscription {
    return this.type == ProductType.autoRenewableSubscription;
  }

  bool get isTypeNonRenewingSubscription {
    return this.type == ProductType.nonRenewingSubscription;
  }

  bool get hasError {
    return this.error?.isNotEmpty == true;
  }

  bool get noError {
    return this.error?.isEmpty ?? true;
  }

  String get errorRequired {
    return this.error ?? (throw StateError('error is required but was null'));
  }
}

extension SubscriptionSerialization on Subscription {
  Map<String, dynamic> toJson() {
    return _$SubscriptionToJson(this);
  }
}

enum Subscription$ {
  id,
  title,
  description,
  price,
  rawPrice,
  currencyCode,
  type,
  isPurchased,
  error,
}

class SubscriptionPatch extends PatchBase<Subscription, Subscription$> {
  Subscription applyTo(Subscription entity) {
    return entity.patchWithSubscription(this);
  }

  SubscriptionPatch withId(String? value) {
    patchMap[Subscription$.id] = value;
    return this;
  }

  SubscriptionPatch withTitle(String? value) {
    patchMap[Subscription$.title] = value;
    return this;
  }

  SubscriptionPatch withDescription(String? value) {
    patchMap[Subscription$.description] = value;
    return this;
  }

  SubscriptionPatch withPrice(String? value) {
    patchMap[Subscription$.price] = value;
    return this;
  }

  SubscriptionPatch withRawPrice(String? value) {
    patchMap[Subscription$.rawPrice] = value;
    return this;
  }

  SubscriptionPatch withCurrencyCode(String? value) {
    patchMap[Subscription$.currencyCode] = value;
    return this;
  }

  SubscriptionPatch withType(ProductType? value) {
    patchMap[Subscription$.type] = value;
    return this;
  }

  SubscriptionPatch withIsPurchased(bool? value) {
    patchMap[Subscription$.isPurchased] = value;
    return this;
  }

  SubscriptionPatch withError(String? value) {
    patchMap[Subscription$.error] = value;
    return this;
  }
}

/// Field descriptors for [Subscription] query construction
abstract final class SubscriptionFields {
  static const id = Field<Subscription, String>('id', _$id);

  static const title = Field<Subscription, String>('title', _$title);

  static const description = Field<Subscription, String>(
    'description',
    _$description,
  );

  static const price = Field<Subscription, String>('price', _$price);

  static const rawPrice = Field<Subscription, String>('rawPrice', _$rawPrice);

  static const currencyCode = Field<Subscription, String>(
    'currencyCode',
    _$currencyCode,
  );

  static const type = Field<Subscription, ProductType>('type', _$type);

  static const isPurchased = Field<Subscription, bool>(
    'isPurchased',
    _$isPurchased,
  );

  static const error = Field<Subscription, String?>('error', _$error);

  static String _$id(Subscription e) {
    return e.id;
  }

  static String _$title(Subscription e) {
    return e.title;
  }

  static String _$description(Subscription e) {
    return e.description;
  }

  static String _$price(Subscription e) {
    return e.price;
  }

  static String _$rawPrice(Subscription e) {
    return e.rawPrice;
  }

  static String _$currencyCode(Subscription e) {
    return e.currencyCode;
  }

  static ProductType _$type(Subscription e) {
    return e.type;
  }

  static bool _$isPurchased(Subscription e) {
    return e.isPurchased;
  }

  static String? _$error(Subscription e) {
    return e.error;
  }
}

extension SubscriptionCompareE on Subscription {
  Map<String, dynamic> compareToSubscription(Subscription other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (description != other.description) {
      diff['description'] = () => other.description;
    }

    if (price != other.price) {
      diff['price'] = () => other.price;
    }

    if (rawPrice != other.rawPrice) {
      diff['rawPrice'] = () => other.rawPrice;
    }

    if (currencyCode != other.currencyCode) {
      diff['currencyCode'] = () => other.currencyCode;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (isPurchased != other.isPurchased) {
      diff['isPurchased'] = () => other.isPurchased;
    }

    if (error != other.error) {
      diff['error'] = () => other.error;
    }
    return diff;
  }
}
