// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'price_alert.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class PriceAlert {
  PriceAlert({
    required String this.id,
    required String this.listingId,
    String? this.listingTitle,
    String? this.listingImageUrl,
    required double this.targetPrice,
    required double this.currentPrice,
    required FeedbackType this.type,
    required DateTime this.createdAt,
    DateTime? this.notifiedAt,
    required bool this.isActive,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) =>
      _$PriceAlertFromJson(json);

  final String id;

  final String listingId;

  final String? listingTitle;

  final String? listingImageUrl;

  final double targetPrice;

  final double currentPrice;

  final FeedbackType type;

  final DateTime createdAt;

  final DateTime? notifiedAt;

  final bool isActive;

  PriceAlert copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    double? targetPrice,
    double? currentPrice,
    FeedbackType? type,
    DateTime? createdAt,
    DateTime? notifiedAt,
    bool? isActive,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImageUrl: listingImageUrl ?? this.listingImageUrl,
      targetPrice: targetPrice ?? this.targetPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  PriceAlert copyWithField<T>(Field<PriceAlert, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'listingId':
        return copyWith(listingId: value as String);
      case 'listingTitle':
        return copyWith(listingTitle: value as String?);
      case 'listingImageUrl':
        return copyWith(listingImageUrl: value as String?);
      case 'targetPrice':
        return copyWith(targetPrice: value as double);
      case 'currentPrice':
        return copyWith(currentPrice: value as double);
      case 'type':
        return copyWith(type: value as FeedbackType);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      case 'notifiedAt':
        return copyWith(notifiedAt: value as DateTime?);
      case 'isActive':
        return copyWith(isActive: value as bool);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'PriceAlert has no settable field with this name',
        );
    }
  }

  PriceAlert copyWithPriceAlert({
    String? id,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    double? targetPrice,
    double? currentPrice,
    FeedbackType? type,
    DateTime? createdAt,
    DateTime? notifiedAt,
    bool? isActive,
  }) {
    return copyWith(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      listingImageUrl: listingImageUrl,
      targetPrice: targetPrice,
      currentPrice: currentPrice,
      type: type,
      createdAt: createdAt,
      notifiedAt: notifiedAt,
      isActive: isActive,
    );
  }

  PriceAlert patchWithPriceAlert([PriceAlertPatch? patchInput]) {
    final _patcher = patchInput ?? PriceAlertPatch();
    final _patchMap = _patcher.patchMap;
    return PriceAlert(
      id: _patchMap.containsKey(PriceAlert$.id)
          ? ((_patchMap[PriceAlert$.id] is Function)
                    ? _patchMap[PriceAlert$.id](this.id)
                    : (_patchMap[PriceAlert$.id] is Patch)
                    ? _patchMap[PriceAlert$.id].applyTo(this.id)
                    : _patchMap[PriceAlert$.id])
                as String
          : this.id,
      listingId: _patchMap.containsKey(PriceAlert$.listingId)
          ? ((_patchMap[PriceAlert$.listingId] is Function)
                    ? _patchMap[PriceAlert$.listingId](this.listingId)
                    : (_patchMap[PriceAlert$.listingId] is Patch)
                    ? _patchMap[PriceAlert$.listingId].applyTo(this.listingId)
                    : _patchMap[PriceAlert$.listingId])
                as String
          : this.listingId,
      listingTitle: _patchMap.containsKey(PriceAlert$.listingTitle)
          ? ((_patchMap[PriceAlert$.listingTitle] is Function)
                    ? _patchMap[PriceAlert$.listingTitle](this.listingTitle)
                    : (_patchMap[PriceAlert$.listingTitle] is Patch)
                    ? _patchMap[PriceAlert$.listingTitle].applyTo(
                        this.listingTitle,
                      )
                    : _patchMap[PriceAlert$.listingTitle])
                as String?
          : this.listingTitle,
      listingImageUrl: _patchMap.containsKey(PriceAlert$.listingImageUrl)
          ? ((_patchMap[PriceAlert$.listingImageUrl] is Function)
                    ? _patchMap[PriceAlert$.listingImageUrl](
                        this.listingImageUrl,
                      )
                    : (_patchMap[PriceAlert$.listingImageUrl] is Patch)
                    ? _patchMap[PriceAlert$.listingImageUrl].applyTo(
                        this.listingImageUrl,
                      )
                    : _patchMap[PriceAlert$.listingImageUrl])
                as String?
          : this.listingImageUrl,
      targetPrice: _patchMap.containsKey(PriceAlert$.targetPrice)
          ? ((_patchMap[PriceAlert$.targetPrice] is Function)
                    ? _patchMap[PriceAlert$.targetPrice](this.targetPrice)
                    : (_patchMap[PriceAlert$.targetPrice] is Patch)
                    ? _patchMap[PriceAlert$.targetPrice].applyTo(
                        this.targetPrice,
                      )
                    : _patchMap[PriceAlert$.targetPrice])
                as double
          : this.targetPrice,
      currentPrice: _patchMap.containsKey(PriceAlert$.currentPrice)
          ? ((_patchMap[PriceAlert$.currentPrice] is Function)
                    ? _patchMap[PriceAlert$.currentPrice](this.currentPrice)
                    : (_patchMap[PriceAlert$.currentPrice] is Patch)
                    ? _patchMap[PriceAlert$.currentPrice].applyTo(
                        this.currentPrice,
                      )
                    : _patchMap[PriceAlert$.currentPrice])
                as double
          : this.currentPrice,
      type: _patchMap.containsKey(PriceAlert$.type)
          ? ((_patchMap[PriceAlert$.type] is Function)
                    ? _patchMap[PriceAlert$.type](this.type)
                    : (_patchMap[PriceAlert$.type] is Patch)
                    ? _patchMap[PriceAlert$.type].applyTo(this.type)
                    : _patchMap[PriceAlert$.type])
                as FeedbackType
          : this.type,
      createdAt: _patchMap.containsKey(PriceAlert$.createdAt)
          ? ((_patchMap[PriceAlert$.createdAt] is Function)
                    ? _patchMap[PriceAlert$.createdAt](this.createdAt)
                    : (_patchMap[PriceAlert$.createdAt] is Patch)
                    ? _patchMap[PriceAlert$.createdAt].applyTo(this.createdAt)
                    : _patchMap[PriceAlert$.createdAt])
                as DateTime
          : this.createdAt,
      notifiedAt: _patchMap.containsKey(PriceAlert$.notifiedAt)
          ? ((_patchMap[PriceAlert$.notifiedAt] is Function)
                    ? _patchMap[PriceAlert$.notifiedAt](this.notifiedAt)
                    : (_patchMap[PriceAlert$.notifiedAt] is Patch)
                    ? _patchMap[PriceAlert$.notifiedAt].applyTo(this.notifiedAt)
                    : _patchMap[PriceAlert$.notifiedAt])
                as DateTime?
          : this.notifiedAt,
      isActive: _patchMap.containsKey(PriceAlert$.isActive)
          ? ((_patchMap[PriceAlert$.isActive] is Function)
                    ? _patchMap[PriceAlert$.isActive](this.isActive)
                    : (_patchMap[PriceAlert$.isActive] is Patch)
                    ? _patchMap[PriceAlert$.isActive].applyTo(this.isActive)
                    : _patchMap[PriceAlert$.isActive])
                as bool
          : this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PriceAlert &&
        id == other.id &&
        listingId == other.listingId &&
        listingTitle == other.listingTitle &&
        listingImageUrl == other.listingImageUrl &&
        targetPrice == other.targetPrice &&
        currentPrice == other.currentPrice &&
        type == other.type &&
        createdAt == other.createdAt &&
        notifiedAt == other.notifiedAt &&
        isActive == other.isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.listingId,
      this.listingTitle,
      this.listingImageUrl,
      this.targetPrice,
      this.currentPrice,
      this.type,
      this.createdAt,
      this.notifiedAt,
      this.isActive,
    );
  }

  @override
  String toString() {
    return 'PriceAlert(' +
        'id: ${id}' +
        ', ' +
        'listingId: ${listingId}' +
        ', ' +
        'listingTitle: ${listingTitle}' +
        ', ' +
        'listingImageUrl: ${listingImageUrl}' +
        ', ' +
        'targetPrice: ${targetPrice}' +
        ', ' +
        'currentPrice: ${currentPrice}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'notifiedAt: ${notifiedAt}' +
        ', ' +
        'isActive: ${isActive})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$PriceAlertToJson(this);
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

extension PriceAlertPropertyHelpers on PriceAlert {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasListingId {
    return this.listingId.isNotEmpty;
  }

  bool get noListingId {
    return this.listingId.isEmpty;
  }

  bool get hasListingTitle {
    return this.listingTitle?.isNotEmpty == true;
  }

  bool get noListingTitle {
    return this.listingTitle?.isEmpty ?? true;
  }

  String get listingTitleRequired {
    return this.listingTitle ??
        (throw StateError('listingTitle is required but was null'));
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

  bool get isTypeError {
    return this.type == FeedbackType.error;
  }

  bool get isTypeSuggestion {
    return this.type == FeedbackType.suggestion;
  }

  bool get isTypeThanks {
    return this.type == FeedbackType.thanks;
  }

  bool get hasNotifiedAt {
    return this.notifiedAt != null;
  }

  bool get noNotifiedAt {
    return this.notifiedAt == null;
  }

  DateTime get notifiedAtRequired {
    return this.notifiedAt ??
        (throw StateError('notifiedAt is required but was null'));
  }
}

extension PriceAlertSerialization on PriceAlert {
  Map<String, dynamic> toJson() {
    return _$PriceAlertToJson(this);
  }
}

enum PriceAlert$ {
  id,
  listingId,
  listingTitle,
  listingImageUrl,
  targetPrice,
  currentPrice,
  type,
  createdAt,
  notifiedAt,
  isActive,
}

class PriceAlertPatch extends PatchBase<PriceAlert, PriceAlert$> {
  PriceAlert applyTo(PriceAlert entity) {
    return entity.patchWithPriceAlert(this);
  }

  PriceAlertPatch withId(String? value) {
    patchMap[PriceAlert$.id] = value;
    return this;
  }

  PriceAlertPatch withListingId(String? value) {
    patchMap[PriceAlert$.listingId] = value;
    return this;
  }

  PriceAlertPatch withListingTitle(String? value) {
    patchMap[PriceAlert$.listingTitle] = value;
    return this;
  }

  PriceAlertPatch withListingImageUrl(String? value) {
    patchMap[PriceAlert$.listingImageUrl] = value;
    return this;
  }

  PriceAlertPatch withTargetPrice(double? value) {
    patchMap[PriceAlert$.targetPrice] = value;
    return this;
  }

  PriceAlertPatch withCurrentPrice(double? value) {
    patchMap[PriceAlert$.currentPrice] = value;
    return this;
  }

  PriceAlertPatch withType(FeedbackType? value) {
    patchMap[PriceAlert$.type] = value;
    return this;
  }

  PriceAlertPatch withCreatedAt(DateTime? value) {
    patchMap[PriceAlert$.createdAt] = value;
    return this;
  }

  PriceAlertPatch withNotifiedAt(DateTime? value) {
    patchMap[PriceAlert$.notifiedAt] = value;
    return this;
  }

  PriceAlertPatch withIsActive(bool? value) {
    patchMap[PriceAlert$.isActive] = value;
    return this;
  }
}

/// Field descriptors for [PriceAlert] query construction
abstract final class PriceAlertFields {
  static const id = Field<PriceAlert, String>('id', _$id);

  static const listingId = Field<PriceAlert, String>('listingId', _$listingId);

  static const listingTitle = Field<PriceAlert, String?>(
    'listingTitle',
    _$listingTitle,
  );

  static const listingImageUrl = Field<PriceAlert, String?>(
    'listingImageUrl',
    _$listingImageUrl,
  );

  static const targetPrice = Field<PriceAlert, double>(
    'targetPrice',
    _$targetPrice,
  );

  static const currentPrice = Field<PriceAlert, double>(
    'currentPrice',
    _$currentPrice,
  );

  static const type = Field<PriceAlert, FeedbackType>('type', _$type);

  static const createdAt = Field<PriceAlert, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static const notifiedAt = Field<PriceAlert, DateTime?>(
    'notifiedAt',
    _$notifiedAt,
  );

  static const isActive = Field<PriceAlert, bool>('isActive', _$isActive);

  static String _$id(PriceAlert e) {
    return e.id;
  }

  static String _$listingId(PriceAlert e) {
    return e.listingId;
  }

  static String? _$listingTitle(PriceAlert e) {
    return e.listingTitle;
  }

  static String? _$listingImageUrl(PriceAlert e) {
    return e.listingImageUrl;
  }

  static double _$targetPrice(PriceAlert e) {
    return e.targetPrice;
  }

  static double _$currentPrice(PriceAlert e) {
    return e.currentPrice;
  }

  static FeedbackType _$type(PriceAlert e) {
    return e.type;
  }

  static DateTime _$createdAt(PriceAlert e) {
    return e.createdAt;
  }

  static DateTime? _$notifiedAt(PriceAlert e) {
    return e.notifiedAt;
  }

  static bool _$isActive(PriceAlert e) {
    return e.isActive;
  }
}

extension PriceAlertCompareE on PriceAlert {
  Map<String, dynamic> compareToPriceAlert(PriceAlert other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
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

    if (targetPrice != other.targetPrice) {
      diff['targetPrice'] = () => other.targetPrice;
    }

    if (currentPrice != other.currentPrice) {
      diff['currentPrice'] = () => other.currentPrice;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (notifiedAt != other.notifiedAt) {
      diff['notifiedAt'] = () => other.notifiedAt;
    }

    if (isActive != other.isActive) {
      diff['isActive'] = () => other.isActive;
    }
    return diff;
  }
}
