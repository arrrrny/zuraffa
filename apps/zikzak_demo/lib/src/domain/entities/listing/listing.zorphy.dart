// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'listing.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Listing {
  Listing({
    required String this.id,
    required String this.title,
    List<ListingOffer>? this.offers,
    List<Listing>? this.similarListings,
    List<Listing>? this.variations,
    bool? this.hasGoogleShoppingMatch,
    DateTime? this.createdAt,
    DateTime? this.updatedAt,
    String? this.groupId,
    String? this.reviewSummary,
    required bool this.enableAskZikZak,
    String? this.colorName,
    String? this.thumbnailUrl,
  });

  factory Listing.fromJson(Map<String, dynamic> json) =>
      _$ListingFromJson(json);

  final String id;

  final String title;

  final List<ListingOffer>? offers;

  final List<Listing>? similarListings;

  final List<Listing>? variations;

  final bool? hasGoogleShoppingMatch;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final String? groupId;

  final String? reviewSummary;

  final bool enableAskZikZak;

  final String? colorName;

  final String? thumbnailUrl;

  Listing copyWith({
    String? id,
    String? title,
    List<ListingOffer>? offers,
    List<Listing>? similarListings,
    List<Listing>? variations,
    bool? hasGoogleShoppingMatch,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? groupId,
    String? reviewSummary,
    bool? enableAskZikZak,
    String? colorName,
    String? thumbnailUrl,
  }) {
    return Listing(
      id: id ?? this.id,
      title: title ?? this.title,
      offers: offers ?? this.offers,
      similarListings: similarListings ?? this.similarListings,
      variations: variations ?? this.variations,
      hasGoogleShoppingMatch:
          hasGoogleShoppingMatch ?? this.hasGoogleShoppingMatch,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      groupId: groupId ?? this.groupId,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      enableAskZikZak: enableAskZikZak ?? this.enableAskZikZak,
      colorName: colorName ?? this.colorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Listing copyWithField<T>(Field<Listing, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'offers':
        return copyWith(offers: value as List<ListingOffer>?);
      case 'similarListings':
        return copyWith(similarListings: value as List<Listing>?);
      case 'variations':
        return copyWith(variations: value as List<Listing>?);
      case 'hasGoogleShoppingMatch':
        return copyWith(hasGoogleShoppingMatch: value as bool?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime?);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime?);
      case 'groupId':
        return copyWith(groupId: value as String?);
      case 'reviewSummary':
        return copyWith(reviewSummary: value as String?);
      case 'enableAskZikZak':
        return copyWith(enableAskZikZak: value as bool);
      case 'colorName':
        return copyWith(colorName: value as String?);
      case 'thumbnailUrl':
        return copyWith(thumbnailUrl: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Listing has no settable field with this name',
        );
    }
  }

  Listing copyWithListing({
    String? id,
    String? title,
    List<ListingOffer>? offers,
    List<Listing>? similarListings,
    List<Listing>? variations,
    bool? hasGoogleShoppingMatch,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? groupId,
    String? reviewSummary,
    bool? enableAskZikZak,
    String? colorName,
    String? thumbnailUrl,
  }) {
    return copyWith(
      id: id,
      title: title,
      offers: offers,
      similarListings: similarListings,
      variations: variations,
      hasGoogleShoppingMatch: hasGoogleShoppingMatch,
      createdAt: createdAt,
      updatedAt: updatedAt,
      groupId: groupId,
      reviewSummary: reviewSummary,
      enableAskZikZak: enableAskZikZak,
      colorName: colorName,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Listing patchWithListing([ListingPatch? patchInput]) {
    final _patcher = patchInput ?? ListingPatch();
    final _patchMap = _patcher.patchMap;
    return Listing(
      id: _patchMap.containsKey(Listing$.id)
          ? ((_patchMap[Listing$.id] is Function)
                    ? _patchMap[Listing$.id](this.id)
                    : (_patchMap[Listing$.id] is Patch)
                    ? _patchMap[Listing$.id].applyTo(this.id)
                    : _patchMap[Listing$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(Listing$.title)
          ? ((_patchMap[Listing$.title] is Function)
                    ? _patchMap[Listing$.title](this.title)
                    : (_patchMap[Listing$.title] is Patch)
                    ? _patchMap[Listing$.title].applyTo(this.title)
                    : _patchMap[Listing$.title])
                as String
          : this.title,
      offers: _patchMap.containsKey(Listing$.offers)
          ? ((_patchMap[Listing$.offers] is Function)
                    ? _patchMap[Listing$.offers](this.offers)
                    : (_patchMap[Listing$.offers] is Patch)
                    ? _patchMap[Listing$.offers].applyTo(this.offers)
                    : _patchMap[Listing$.offers])
                as List<ListingOffer>?
          : this.offers,
      similarListings: _patchMap.containsKey(Listing$.similarListings)
          ? ((_patchMap[Listing$.similarListings] is Function)
                    ? _patchMap[Listing$.similarListings](this.similarListings)
                    : (_patchMap[Listing$.similarListings] is Patch)
                    ? _patchMap[Listing$.similarListings].applyTo(
                        this.similarListings,
                      )
                    : _patchMap[Listing$.similarListings])
                as List<Listing>?
          : this.similarListings,
      variations: _patchMap.containsKey(Listing$.variations)
          ? ((_patchMap[Listing$.variations] is Function)
                    ? _patchMap[Listing$.variations](this.variations)
                    : (_patchMap[Listing$.variations] is Patch)
                    ? _patchMap[Listing$.variations].applyTo(this.variations)
                    : _patchMap[Listing$.variations])
                as List<Listing>?
          : this.variations,
      hasGoogleShoppingMatch:
          _patchMap.containsKey(Listing$.hasGoogleShoppingMatch)
          ? ((_patchMap[Listing$.hasGoogleShoppingMatch] is Function)
                    ? _patchMap[Listing$.hasGoogleShoppingMatch](
                        this.hasGoogleShoppingMatch,
                      )
                    : (_patchMap[Listing$.hasGoogleShoppingMatch] is Patch)
                    ? _patchMap[Listing$.hasGoogleShoppingMatch].applyTo(
                        this.hasGoogleShoppingMatch,
                      )
                    : _patchMap[Listing$.hasGoogleShoppingMatch])
                as bool?
          : this.hasGoogleShoppingMatch,
      createdAt: _patchMap.containsKey(Listing$.createdAt)
          ? ((_patchMap[Listing$.createdAt] is Function)
                    ? _patchMap[Listing$.createdAt](this.createdAt)
                    : (_patchMap[Listing$.createdAt] is Patch)
                    ? _patchMap[Listing$.createdAt].applyTo(this.createdAt)
                    : _patchMap[Listing$.createdAt])
                as DateTime?
          : this.createdAt,
      updatedAt: _patchMap.containsKey(Listing$.updatedAt)
          ? ((_patchMap[Listing$.updatedAt] is Function)
                    ? _patchMap[Listing$.updatedAt](this.updatedAt)
                    : (_patchMap[Listing$.updatedAt] is Patch)
                    ? _patchMap[Listing$.updatedAt].applyTo(this.updatedAt)
                    : _patchMap[Listing$.updatedAt])
                as DateTime?
          : this.updatedAt,
      groupId: _patchMap.containsKey(Listing$.groupId)
          ? ((_patchMap[Listing$.groupId] is Function)
                    ? _patchMap[Listing$.groupId](this.groupId)
                    : (_patchMap[Listing$.groupId] is Patch)
                    ? _patchMap[Listing$.groupId].applyTo(this.groupId)
                    : _patchMap[Listing$.groupId])
                as String?
          : this.groupId,
      reviewSummary: _patchMap.containsKey(Listing$.reviewSummary)
          ? ((_patchMap[Listing$.reviewSummary] is Function)
                    ? _patchMap[Listing$.reviewSummary](this.reviewSummary)
                    : (_patchMap[Listing$.reviewSummary] is Patch)
                    ? _patchMap[Listing$.reviewSummary].applyTo(
                        this.reviewSummary,
                      )
                    : _patchMap[Listing$.reviewSummary])
                as String?
          : this.reviewSummary,
      enableAskZikZak: _patchMap.containsKey(Listing$.enableAskZikZak)
          ? ((_patchMap[Listing$.enableAskZikZak] is Function)
                    ? _patchMap[Listing$.enableAskZikZak](this.enableAskZikZak)
                    : (_patchMap[Listing$.enableAskZikZak] is Patch)
                    ? _patchMap[Listing$.enableAskZikZak].applyTo(
                        this.enableAskZikZak,
                      )
                    : _patchMap[Listing$.enableAskZikZak])
                as bool
          : this.enableAskZikZak,
      colorName: _patchMap.containsKey(Listing$.colorName)
          ? ((_patchMap[Listing$.colorName] is Function)
                    ? _patchMap[Listing$.colorName](this.colorName)
                    : (_patchMap[Listing$.colorName] is Patch)
                    ? _patchMap[Listing$.colorName].applyTo(this.colorName)
                    : _patchMap[Listing$.colorName])
                as String?
          : this.colorName,
      thumbnailUrl: _patchMap.containsKey(Listing$.thumbnailUrl)
          ? ((_patchMap[Listing$.thumbnailUrl] is Function)
                    ? _patchMap[Listing$.thumbnailUrl](this.thumbnailUrl)
                    : (_patchMap[Listing$.thumbnailUrl] is Patch)
                    ? _patchMap[Listing$.thumbnailUrl].applyTo(
                        this.thumbnailUrl,
                      )
                    : _patchMap[Listing$.thumbnailUrl])
                as String?
          : this.thumbnailUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Listing &&
        id == other.id &&
        title == other.title &&
        offers == other.offers &&
        similarListings == other.similarListings &&
        variations == other.variations &&
        hasGoogleShoppingMatch == other.hasGoogleShoppingMatch &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        groupId == other.groupId &&
        reviewSummary == other.reviewSummary &&
        enableAskZikZak == other.enableAskZikZak &&
        colorName == other.colorName &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.offers,
      this.similarListings,
      this.variations,
      this.hasGoogleShoppingMatch,
      this.createdAt,
      this.updatedAt,
      this.groupId,
      this.reviewSummary,
      this.enableAskZikZak,
      this.colorName,
      this.thumbnailUrl,
    );
  }

  @override
  String toString() {
    return 'Listing(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'offers: ${offers}' +
        ', ' +
        'similarListings: ${similarListings}' +
        ', ' +
        'variations: ${variations}' +
        ', ' +
        'hasGoogleShoppingMatch: ${hasGoogleShoppingMatch}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'updatedAt: ${updatedAt}' +
        ', ' +
        'groupId: ${groupId}' +
        ', ' +
        'reviewSummary: ${reviewSummary}' +
        ', ' +
        'enableAskZikZak: ${enableAskZikZak}' +
        ', ' +
        'colorName: ${colorName}' +
        ', ' +
        'thumbnailUrl: ${thumbnailUrl})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ListingToJson(this);
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

extension ListingPropertyHelpers on Listing {
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

  List<ListingOffer> get offersRequired {
    return this.offers ?? (throw StateError('offers is required but was null'));
  }

  bool get hasOffers {
    return this.offers?.isNotEmpty ?? false;
  }

  bool get noOffers {
    return this.offers?.isEmpty ?? true;
  }

  List<Listing> get similarListingsRequired {
    return this.similarListings ??
        (throw StateError('similarListings is required but was null'));
  }

  bool get hasSimilarListings {
    return this.similarListings?.isNotEmpty ?? false;
  }

  bool get noSimilarListings {
    return this.similarListings?.isEmpty ?? true;
  }

  List<Listing> get variationsRequired {
    return this.variations ??
        (throw StateError('variations is required but was null'));
  }

  bool get hasVariations {
    return this.variations?.isNotEmpty ?? false;
  }

  bool get noVariations {
    return this.variations?.isEmpty ?? true;
  }

  bool get hasHasGoogleShoppingMatch {
    return this.hasGoogleShoppingMatch != null;
  }

  bool get noHasGoogleShoppingMatch {
    return this.hasGoogleShoppingMatch == null;
  }

  bool get hasGoogleShoppingMatchRequired {
    return this.hasGoogleShoppingMatch ??
        (throw StateError('hasGoogleShoppingMatch is required but was null'));
  }

  bool get hasCreatedAt {
    return this.createdAt != null;
  }

  bool get noCreatedAt {
    return this.createdAt == null;
  }

  DateTime get createdAtRequired {
    return this.createdAt ??
        (throw StateError('createdAt is required but was null'));
  }

  bool get hasUpdatedAt {
    return this.updatedAt != null;
  }

  bool get noUpdatedAt {
    return this.updatedAt == null;
  }

  DateTime get updatedAtRequired {
    return this.updatedAt ??
        (throw StateError('updatedAt is required but was null'));
  }

  bool get hasGroupId {
    return this.groupId?.isNotEmpty == true;
  }

  bool get noGroupId {
    return this.groupId?.isEmpty ?? true;
  }

  String get groupIdRequired {
    return this.groupId ??
        (throw StateError('groupId is required but was null'));
  }

  bool get hasReviewSummary {
    return this.reviewSummary?.isNotEmpty == true;
  }

  bool get noReviewSummary {
    return this.reviewSummary?.isEmpty ?? true;
  }

  String get reviewSummaryRequired {
    return this.reviewSummary ??
        (throw StateError('reviewSummary is required but was null'));
  }

  bool get hasColorName {
    return this.colorName?.isNotEmpty == true;
  }

  bool get noColorName {
    return this.colorName?.isEmpty ?? true;
  }

  String get colorNameRequired {
    return this.colorName ??
        (throw StateError('colorName is required but was null'));
  }

  bool get hasThumbnailUrl {
    return this.thumbnailUrl?.isNotEmpty == true;
  }

  bool get noThumbnailUrl {
    return this.thumbnailUrl?.isEmpty ?? true;
  }

  String get thumbnailUrlRequired {
    return this.thumbnailUrl ??
        (throw StateError('thumbnailUrl is required but was null'));
  }
}

extension ListingSerialization on Listing {
  Map<String, dynamic> toJson() {
    return _$ListingToJson(this);
  }
}

enum Listing$ {
  id,
  title,
  offers,
  similarListings,
  variations,
  hasGoogleShoppingMatch,
  createdAt,
  updatedAt,
  groupId,
  reviewSummary,
  enableAskZikZak,
  colorName,
  thumbnailUrl,
}

class ListingPatch extends PatchBase<Listing, Listing$> {
  Listing applyTo(Listing entity) {
    return entity.patchWithListing(this);
  }

  ListingPatch withId(String? value) {
    patchMap[Listing$.id] = value;
    return this;
  }

  ListingPatch withTitle(String? value) {
    patchMap[Listing$.title] = value;
    return this;
  }

  ListingPatch withOffers(List<ListingOffer>? value) {
    patchMap[Listing$.offers] = value;
    return this;
  }

  ListingPatch updateOffersAt(
    int index,
    ListingOfferPatch Function(ListingOfferPatch) patch,
  ) {
    patchMap[Listing$.offers] = (List<dynamic> list) {
      var updatedList = List<ListingOffer>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          ListingOfferPatch(),
        ).applyTo(updatedList[index] as ListingOffer);
      }
      return updatedList;
    };
    return this;
  }

  ListingPatch withSimilarListings(List<Listing>? value) {
    patchMap[Listing$.similarListings] = value;
    return this;
  }

  ListingPatch updateSimilarListingsAt(
    int index,
    ListingPatch Function(ListingPatch) patch,
  ) {
    patchMap[Listing$.similarListings] = (List<dynamic> list) {
      var updatedList = List<Listing>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          ListingPatch(),
        ).applyTo(updatedList[index] as Listing);
      }
      return updatedList;
    };
    return this;
  }

  ListingPatch withVariations(List<Listing>? value) {
    patchMap[Listing$.variations] = value;
    return this;
  }

  ListingPatch updateVariationsAt(
    int index,
    ListingPatch Function(ListingPatch) patch,
  ) {
    patchMap[Listing$.variations] = (List<dynamic> list) {
      var updatedList = List<Listing>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          ListingPatch(),
        ).applyTo(updatedList[index] as Listing);
      }
      return updatedList;
    };
    return this;
  }

  ListingPatch withHasGoogleShoppingMatch(bool? value) {
    patchMap[Listing$.hasGoogleShoppingMatch] = value;
    return this;
  }

  ListingPatch withCreatedAt(DateTime? value) {
    patchMap[Listing$.createdAt] = value;
    return this;
  }

  ListingPatch withUpdatedAt(DateTime? value) {
    patchMap[Listing$.updatedAt] = value;
    return this;
  }

  ListingPatch withGroupId(String? value) {
    patchMap[Listing$.groupId] = value;
    return this;
  }

  ListingPatch withReviewSummary(String? value) {
    patchMap[Listing$.reviewSummary] = value;
    return this;
  }

  ListingPatch withEnableAskZikZak(bool? value) {
    patchMap[Listing$.enableAskZikZak] = value;
    return this;
  }

  ListingPatch withColorName(String? value) {
    patchMap[Listing$.colorName] = value;
    return this;
  }

  ListingPatch withThumbnailUrl(String? value) {
    patchMap[Listing$.thumbnailUrl] = value;
    return this;
  }
}

/// Field descriptors for [Listing] query construction
abstract final class ListingFields {
  static const id = Field<Listing, String>('id', _$id);

  static const title = Field<Listing, String>('title', _$title);

  static const offers = Field<Listing, List<ListingOffer>?>('offers', _$offers);

  static const similarListings = Field<Listing, List<Listing>?>(
    'similarListings',
    _$similarListings,
  );

  static const variations = Field<Listing, List<Listing>?>(
    'variations',
    _$variations,
  );

  static const hasGoogleShoppingMatch = Field<Listing, bool?>(
    'hasGoogleShoppingMatch',
    _$hasGoogleShoppingMatch,
  );

  static const createdAt = Field<Listing, DateTime?>('createdAt', _$createdAt);

  static const updatedAt = Field<Listing, DateTime?>('updatedAt', _$updatedAt);

  static const groupId = Field<Listing, String?>('groupId', _$groupId);

  static const reviewSummary = Field<Listing, String?>(
    'reviewSummary',
    _$reviewSummary,
  );

  static const enableAskZikZak = Field<Listing, bool>(
    'enableAskZikZak',
    _$enableAskZikZak,
  );

  static const colorName = Field<Listing, String?>('colorName', _$colorName);

  static const thumbnailUrl = Field<Listing, String?>(
    'thumbnailUrl',
    _$thumbnailUrl,
  );

  static String _$id(Listing e) {
    return e.id;
  }

  static String _$title(Listing e) {
    return e.title;
  }

  static List<ListingOffer>? _$offers(Listing e) {
    return e.offers;
  }

  static List<Listing>? _$similarListings(Listing e) {
    return e.similarListings;
  }

  static List<Listing>? _$variations(Listing e) {
    return e.variations;
  }

  static bool? _$hasGoogleShoppingMatch(Listing e) {
    return e.hasGoogleShoppingMatch;
  }

  static DateTime? _$createdAt(Listing e) {
    return e.createdAt;
  }

  static DateTime? _$updatedAt(Listing e) {
    return e.updatedAt;
  }

  static String? _$groupId(Listing e) {
    return e.groupId;
  }

  static String? _$reviewSummary(Listing e) {
    return e.reviewSummary;
  }

  static bool _$enableAskZikZak(Listing e) {
    return e.enableAskZikZak;
  }

  static String? _$colorName(Listing e) {
    return e.colorName;
  }

  static String? _$thumbnailUrl(Listing e) {
    return e.thumbnailUrl;
  }
}

extension ListingCompareE on Listing {
  Map<String, dynamic> compareToListing(Listing other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (offers != other.offers) {
      diff['offers'] = () => other.offers;
    }

    if (similarListings != other.similarListings) {
      diff['similarListings'] = () => other.similarListings;
    }

    if (variations != other.variations) {
      diff['variations'] = () => other.variations;
    }

    if (hasGoogleShoppingMatch != other.hasGoogleShoppingMatch) {
      diff['hasGoogleShoppingMatch'] = () => other.hasGoogleShoppingMatch;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (updatedAt != other.updatedAt) {
      diff['updatedAt'] = () => other.updatedAt;
    }

    if (groupId != other.groupId) {
      diff['groupId'] = () => other.groupId;
    }

    if (reviewSummary != other.reviewSummary) {
      diff['reviewSummary'] = () => other.reviewSummary;
    }

    if (enableAskZikZak != other.enableAskZikZak) {
      diff['enableAskZikZak'] = () => other.enableAskZikZak;
    }

    if (colorName != other.colorName) {
      diff['colorName'] = () => other.colorName;
    }

    if (thumbnailUrl != other.thumbnailUrl) {
      diff['thumbnailUrl'] = () => other.thumbnailUrl;
    }
    return diff;
  }
}
