// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'price_drop_notification.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class PriceDropNotification {
  PriceDropNotification({
    required String this.id,
    required String this.priceAlertId,
    required String this.listingId,
    required String this.listingTitle,
    String? this.listingImageUrl,
    required double this.oldPrice,
    required double this.newPrice,
    double? this.dropPercentage,
    required DateTime this.createdAt,
    required bool this.isRead,
  });

  factory PriceDropNotification.fromJson(Map<String, dynamic> json) =>
      _$PriceDropNotificationFromJson(json);

  final String id;

  final String priceAlertId;

  final String listingId;

  final String listingTitle;

  final String? listingImageUrl;

  final double oldPrice;

  final double newPrice;

  final double? dropPercentage;

  final DateTime createdAt;

  final bool isRead;

  PriceDropNotification copyWith({
    String? id,
    String? priceAlertId,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    double? oldPrice,
    double? newPrice,
    double? dropPercentage,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return PriceDropNotification(
      id: id ?? this.id,
      priceAlertId: priceAlertId ?? this.priceAlertId,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImageUrl: listingImageUrl ?? this.listingImageUrl,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
      dropPercentage: dropPercentage ?? this.dropPercentage,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  PriceDropNotification copyWithField<T>(
    Field<PriceDropNotification, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'priceAlertId':
        return copyWith(priceAlertId: value as String);
      case 'listingId':
        return copyWith(listingId: value as String);
      case 'listingTitle':
        return copyWith(listingTitle: value as String);
      case 'listingImageUrl':
        return copyWith(listingImageUrl: value as String?);
      case 'oldPrice':
        return copyWith(oldPrice: value as double);
      case 'newPrice':
        return copyWith(newPrice: value as double);
      case 'dropPercentage':
        return copyWith(dropPercentage: value as double?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      case 'isRead':
        return copyWith(isRead: value as bool);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'PriceDropNotification has no settable field with this name',
        );
    }
  }

  PriceDropNotification copyWithPriceDropNotification({
    String? id,
    String? priceAlertId,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    double? oldPrice,
    double? newPrice,
    double? dropPercentage,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return copyWith(
      id: id,
      priceAlertId: priceAlertId,
      listingId: listingId,
      listingTitle: listingTitle,
      listingImageUrl: listingImageUrl,
      oldPrice: oldPrice,
      newPrice: newPrice,
      dropPercentage: dropPercentage,
      createdAt: createdAt,
      isRead: isRead,
    );
  }

  PriceDropNotification patchWithPriceDropNotification([
    PriceDropNotificationPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? PriceDropNotificationPatch();
    final _patchMap = _patcher.patchMap;
    return PriceDropNotification(
      id: _patchMap.containsKey(PriceDropNotification$.id)
          ? ((_patchMap[PriceDropNotification$.id] is Function)
                    ? _patchMap[PriceDropNotification$.id](this.id)
                    : (_patchMap[PriceDropNotification$.id] is Patch)
                    ? _patchMap[PriceDropNotification$.id].applyTo(this.id)
                    : _patchMap[PriceDropNotification$.id])
                as String
          : this.id,
      priceAlertId: _patchMap.containsKey(PriceDropNotification$.priceAlertId)
          ? ((_patchMap[PriceDropNotification$.priceAlertId] is Function)
                    ? _patchMap[PriceDropNotification$.priceAlertId](
                        this.priceAlertId,
                      )
                    : (_patchMap[PriceDropNotification$.priceAlertId] is Patch)
                    ? _patchMap[PriceDropNotification$.priceAlertId].applyTo(
                        this.priceAlertId,
                      )
                    : _patchMap[PriceDropNotification$.priceAlertId])
                as String
          : this.priceAlertId,
      listingId: _patchMap.containsKey(PriceDropNotification$.listingId)
          ? ((_patchMap[PriceDropNotification$.listingId] is Function)
                    ? _patchMap[PriceDropNotification$.listingId](
                        this.listingId,
                      )
                    : (_patchMap[PriceDropNotification$.listingId] is Patch)
                    ? _patchMap[PriceDropNotification$.listingId].applyTo(
                        this.listingId,
                      )
                    : _patchMap[PriceDropNotification$.listingId])
                as String
          : this.listingId,
      listingTitle: _patchMap.containsKey(PriceDropNotification$.listingTitle)
          ? ((_patchMap[PriceDropNotification$.listingTitle] is Function)
                    ? _patchMap[PriceDropNotification$.listingTitle](
                        this.listingTitle,
                      )
                    : (_patchMap[PriceDropNotification$.listingTitle] is Patch)
                    ? _patchMap[PriceDropNotification$.listingTitle].applyTo(
                        this.listingTitle,
                      )
                    : _patchMap[PriceDropNotification$.listingTitle])
                as String
          : this.listingTitle,
      listingImageUrl:
          _patchMap.containsKey(PriceDropNotification$.listingImageUrl)
          ? ((_patchMap[PriceDropNotification$.listingImageUrl] is Function)
                    ? _patchMap[PriceDropNotification$.listingImageUrl](
                        this.listingImageUrl,
                      )
                    : (_patchMap[PriceDropNotification$.listingImageUrl]
                          is Patch)
                    ? _patchMap[PriceDropNotification$.listingImageUrl].applyTo(
                        this.listingImageUrl,
                      )
                    : _patchMap[PriceDropNotification$.listingImageUrl])
                as String?
          : this.listingImageUrl,
      oldPrice: _patchMap.containsKey(PriceDropNotification$.oldPrice)
          ? ((_patchMap[PriceDropNotification$.oldPrice] is Function)
                    ? _patchMap[PriceDropNotification$.oldPrice](this.oldPrice)
                    : (_patchMap[PriceDropNotification$.oldPrice] is Patch)
                    ? _patchMap[PriceDropNotification$.oldPrice].applyTo(
                        this.oldPrice,
                      )
                    : _patchMap[PriceDropNotification$.oldPrice])
                as double
          : this.oldPrice,
      newPrice: _patchMap.containsKey(PriceDropNotification$.newPrice)
          ? ((_patchMap[PriceDropNotification$.newPrice] is Function)
                    ? _patchMap[PriceDropNotification$.newPrice](this.newPrice)
                    : (_patchMap[PriceDropNotification$.newPrice] is Patch)
                    ? _patchMap[PriceDropNotification$.newPrice].applyTo(
                        this.newPrice,
                      )
                    : _patchMap[PriceDropNotification$.newPrice])
                as double
          : this.newPrice,
      dropPercentage:
          _patchMap.containsKey(PriceDropNotification$.dropPercentage)
          ? ((_patchMap[PriceDropNotification$.dropPercentage] is Function)
                    ? _patchMap[PriceDropNotification$.dropPercentage](
                        this.dropPercentage,
                      )
                    : (_patchMap[PriceDropNotification$.dropPercentage]
                          is Patch)
                    ? _patchMap[PriceDropNotification$.dropPercentage].applyTo(
                        this.dropPercentage,
                      )
                    : _patchMap[PriceDropNotification$.dropPercentage])
                as double?
          : this.dropPercentage,
      createdAt: _patchMap.containsKey(PriceDropNotification$.createdAt)
          ? ((_patchMap[PriceDropNotification$.createdAt] is Function)
                    ? _patchMap[PriceDropNotification$.createdAt](
                        this.createdAt,
                      )
                    : (_patchMap[PriceDropNotification$.createdAt] is Patch)
                    ? _patchMap[PriceDropNotification$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[PriceDropNotification$.createdAt])
                as DateTime
          : this.createdAt,
      isRead: _patchMap.containsKey(PriceDropNotification$.isRead)
          ? ((_patchMap[PriceDropNotification$.isRead] is Function)
                    ? _patchMap[PriceDropNotification$.isRead](this.isRead)
                    : (_patchMap[PriceDropNotification$.isRead] is Patch)
                    ? _patchMap[PriceDropNotification$.isRead].applyTo(
                        this.isRead,
                      )
                    : _patchMap[PriceDropNotification$.isRead])
                as bool
          : this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PriceDropNotification &&
        id == other.id &&
        priceAlertId == other.priceAlertId &&
        listingId == other.listingId &&
        listingTitle == other.listingTitle &&
        listingImageUrl == other.listingImageUrl &&
        oldPrice == other.oldPrice &&
        newPrice == other.newPrice &&
        dropPercentage == other.dropPercentage &&
        createdAt == other.createdAt &&
        isRead == other.isRead;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.priceAlertId,
      this.listingId,
      this.listingTitle,
      this.listingImageUrl,
      this.oldPrice,
      this.newPrice,
      this.dropPercentage,
      this.createdAt,
      this.isRead,
    );
  }

  @override
  String toString() {
    return 'PriceDropNotification(' +
        'id: ${id}' +
        ', ' +
        'priceAlertId: ${priceAlertId}' +
        ', ' +
        'listingId: ${listingId}' +
        ', ' +
        'listingTitle: ${listingTitle}' +
        ', ' +
        'listingImageUrl: ${listingImageUrl}' +
        ', ' +
        'oldPrice: ${oldPrice}' +
        ', ' +
        'newPrice: ${newPrice}' +
        ', ' +
        'dropPercentage: ${dropPercentage}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'isRead: ${isRead})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$PriceDropNotificationToJson(this);
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

extension PriceDropNotificationPropertyHelpers on PriceDropNotification {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasPriceAlertId {
    return this.priceAlertId.isNotEmpty;
  }

  bool get noPriceAlertId {
    return this.priceAlertId.isEmpty;
  }

  bool get hasListingId {
    return this.listingId.isNotEmpty;
  }

  bool get noListingId {
    return this.listingId.isEmpty;
  }

  bool get hasListingTitle {
    return this.listingTitle.isNotEmpty;
  }

  bool get noListingTitle {
    return this.listingTitle.isEmpty;
  }

  bool get hasListingImageUrl {
    return this.listingImageUrl?.isNotEmpty == true;
  }

  bool get noListingImageUrl {
    return this.listingImageUrl?.isEmpty ?? true;
  }

  String get listingImageUrlRequired {
    return this.listingImageUrl ??
        (throw StateError('listingImageUrl is required but was null'));
  }

  bool get hasDropPercentage {
    return this.dropPercentage != null;
  }

  bool get noDropPercentage {
    return this.dropPercentage == null;
  }

  double get dropPercentageRequired {
    return this.dropPercentage ??
        (throw StateError('dropPercentage is required but was null'));
  }
}

extension PriceDropNotificationSerialization on PriceDropNotification {
  Map<String, dynamic> toJson() {
    return _$PriceDropNotificationToJson(this);
  }
}

enum PriceDropNotification$ {
  id,
  priceAlertId,
  listingId,
  listingTitle,
  listingImageUrl,
  oldPrice,
  newPrice,
  dropPercentage,
  createdAt,
  isRead,
}

class PriceDropNotificationPatch
    extends PatchBase<PriceDropNotification, PriceDropNotification$> {
  PriceDropNotification applyTo(PriceDropNotification entity) {
    return entity.patchWithPriceDropNotification(this);
  }

  PriceDropNotificationPatch withId(String? value) {
    patchMap[PriceDropNotification$.id] = value;
    return this;
  }

  PriceDropNotificationPatch withPriceAlertId(String? value) {
    patchMap[PriceDropNotification$.priceAlertId] = value;
    return this;
  }

  PriceDropNotificationPatch withListingId(String? value) {
    patchMap[PriceDropNotification$.listingId] = value;
    return this;
  }

  PriceDropNotificationPatch withListingTitle(String? value) {
    patchMap[PriceDropNotification$.listingTitle] = value;
    return this;
  }

  PriceDropNotificationPatch withListingImageUrl(String? value) {
    patchMap[PriceDropNotification$.listingImageUrl] = value;
    return this;
  }

  PriceDropNotificationPatch withOldPrice(double? value) {
    patchMap[PriceDropNotification$.oldPrice] = value;
    return this;
  }

  PriceDropNotificationPatch withNewPrice(double? value) {
    patchMap[PriceDropNotification$.newPrice] = value;
    return this;
  }

  PriceDropNotificationPatch withDropPercentage(double? value) {
    patchMap[PriceDropNotification$.dropPercentage] = value;
    return this;
  }

  PriceDropNotificationPatch withCreatedAt(DateTime? value) {
    patchMap[PriceDropNotification$.createdAt] = value;
    return this;
  }

  PriceDropNotificationPatch withIsRead(bool? value) {
    patchMap[PriceDropNotification$.isRead] = value;
    return this;
  }
}

/// Field descriptors for [PriceDropNotification] query construction
abstract final class PriceDropNotificationFields {
  static const id = Field<PriceDropNotification, String>('id', _$id);

  static const priceAlertId = Field<PriceDropNotification, String>(
    'priceAlertId',
    _$priceAlertId,
  );

  static const listingId = Field<PriceDropNotification, String>(
    'listingId',
    _$listingId,
  );

  static const listingTitle = Field<PriceDropNotification, String>(
    'listingTitle',
    _$listingTitle,
  );

  static const listingImageUrl = Field<PriceDropNotification, String?>(
    'listingImageUrl',
    _$listingImageUrl,
  );

  static const oldPrice = Field<PriceDropNotification, double>(
    'oldPrice',
    _$oldPrice,
  );

  static const newPrice = Field<PriceDropNotification, double>(
    'newPrice',
    _$newPrice,
  );

  static const dropPercentage = Field<PriceDropNotification, double?>(
    'dropPercentage',
    _$dropPercentage,
  );

  static const createdAt = Field<PriceDropNotification, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static const isRead = Field<PriceDropNotification, bool>('isRead', _$isRead);

  static String _$id(PriceDropNotification e) {
    return e.id;
  }

  static String _$priceAlertId(PriceDropNotification e) {
    return e.priceAlertId;
  }

  static String _$listingId(PriceDropNotification e) {
    return e.listingId;
  }

  static String _$listingTitle(PriceDropNotification e) {
    return e.listingTitle;
  }

  static String? _$listingImageUrl(PriceDropNotification e) {
    return e.listingImageUrl;
  }

  static double _$oldPrice(PriceDropNotification e) {
    return e.oldPrice;
  }

  static double _$newPrice(PriceDropNotification e) {
    return e.newPrice;
  }

  static double? _$dropPercentage(PriceDropNotification e) {
    return e.dropPercentage;
  }

  static DateTime _$createdAt(PriceDropNotification e) {
    return e.createdAt;
  }

  static bool _$isRead(PriceDropNotification e) {
    return e.isRead;
  }
}

extension PriceDropNotificationCompareE on PriceDropNotification {
  Map<String, dynamic> compareToPriceDropNotification(
    PriceDropNotification other,
  ) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (priceAlertId != other.priceAlertId) {
      diff['priceAlertId'] = () => other.priceAlertId;
    }

    if (listingId != other.listingId) {
      diff['listingId'] = () => other.listingId;
    }

    if (listingTitle != other.listingTitle) {
      diff['listingTitle'] = () => other.listingTitle;
    }

    if (listingImageUrl != other.listingImageUrl) {
      diff['listingImageUrl'] = () => other.listingImageUrl;
    }

    if (oldPrice != other.oldPrice) {
      diff['oldPrice'] = () => other.oldPrice;
    }

    if (newPrice != other.newPrice) {
      diff['newPrice'] = () => other.newPrice;
    }

    if (dropPercentage != other.dropPercentage) {
      diff['dropPercentage'] = () => other.dropPercentage;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (isRead != other.isRead) {
      diff['isRead'] = () => other.isRead;
    }
    return diff;
  }
}
