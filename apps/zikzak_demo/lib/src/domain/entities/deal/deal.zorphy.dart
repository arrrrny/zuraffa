// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'deal.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Deal {
  Deal({
    required String this.id,
    required Listing this.listing,
    List<String>? this.badges,
    double? this.discountRate,
    required int this.likeCount,
    required int this.dislikeCount,
    required int this.shareCount,
    required int this.manLikeCount,
    required int this.womanLikeCount,
    required int this.manDislikeCount,
    required int this.womanDislikeCount,
    double? this.ratingScore,
    int? this.reviewCount,
    String? this.aiReasoning,
  });

  factory Deal.fromJson(Map<String, dynamic> json) => _$DealFromJson(json);

  final String id;

  final Listing listing;

  final List<String>? badges;

  final double? discountRate;

  final int likeCount;

  final int dislikeCount;

  final int shareCount;

  final int manLikeCount;

  final int womanLikeCount;

  final int manDislikeCount;

  final int womanDislikeCount;

  final double? ratingScore;

  final int? reviewCount;

  final String? aiReasoning;

  Deal copyWith({
    String? id,
    Listing? listing,
    List<String>? badges,
    double? discountRate,
    int? likeCount,
    int? dislikeCount,
    int? shareCount,
    int? manLikeCount,
    int? womanLikeCount,
    int? manDislikeCount,
    int? womanDislikeCount,
    double? ratingScore,
    int? reviewCount,
    String? aiReasoning,
  }) {
    return Deal(
      id: id ?? this.id,
      listing: listing ?? this.listing,
      badges: badges ?? this.badges,
      discountRate: discountRate ?? this.discountRate,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      shareCount: shareCount ?? this.shareCount,
      manLikeCount: manLikeCount ?? this.manLikeCount,
      womanLikeCount: womanLikeCount ?? this.womanLikeCount,
      manDislikeCount: manDislikeCount ?? this.manDislikeCount,
      womanDislikeCount: womanDislikeCount ?? this.womanDislikeCount,
      ratingScore: ratingScore ?? this.ratingScore,
      reviewCount: reviewCount ?? this.reviewCount,
      aiReasoning: aiReasoning ?? this.aiReasoning,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Deal copyWithField<T>(Field<Deal, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'listing':
        return copyWith(listing: value as Listing);
      case 'badges':
        return copyWith(badges: value as List<String>?);
      case 'discountRate':
        return copyWith(discountRate: value as double?);
      case 'likeCount':
        return copyWith(likeCount: value as int);
      case 'dislikeCount':
        return copyWith(dislikeCount: value as int);
      case 'shareCount':
        return copyWith(shareCount: value as int);
      case 'manLikeCount':
        return copyWith(manLikeCount: value as int);
      case 'womanLikeCount':
        return copyWith(womanLikeCount: value as int);
      case 'manDislikeCount':
        return copyWith(manDislikeCount: value as int);
      case 'womanDislikeCount':
        return copyWith(womanDislikeCount: value as int);
      case 'ratingScore':
        return copyWith(ratingScore: value as double?);
      case 'reviewCount':
        return copyWith(reviewCount: value as int?);
      case 'aiReasoning':
        return copyWith(aiReasoning: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Deal has no settable field with this name',
        );
    }
  }

  Deal copyWithDeal({
    String? id,
    Listing? listing,
    List<String>? badges,
    double? discountRate,
    int? likeCount,
    int? dislikeCount,
    int? shareCount,
    int? manLikeCount,
    int? womanLikeCount,
    int? manDislikeCount,
    int? womanDislikeCount,
    double? ratingScore,
    int? reviewCount,
    String? aiReasoning,
  }) {
    return copyWith(
      id: id,
      listing: listing,
      badges: badges,
      discountRate: discountRate,
      likeCount: likeCount,
      dislikeCount: dislikeCount,
      shareCount: shareCount,
      manLikeCount: manLikeCount,
      womanLikeCount: womanLikeCount,
      manDislikeCount: manDislikeCount,
      womanDislikeCount: womanDislikeCount,
      ratingScore: ratingScore,
      reviewCount: reviewCount,
      aiReasoning: aiReasoning,
    );
  }

  Deal patchWithDeal([DealPatch? patchInput]) {
    final _patcher = patchInput ?? DealPatch();
    final _patchMap = _patcher.patchMap;
    return Deal(
      id: _patchMap.containsKey(Deal$.id)
          ? ((_patchMap[Deal$.id] is Function)
                    ? _patchMap[Deal$.id](this.id)
                    : (_patchMap[Deal$.id] is Patch)
                    ? _patchMap[Deal$.id].applyTo(this.id)
                    : _patchMap[Deal$.id])
                as String
          : this.id,
      listing: _patchMap.containsKey(Deal$.listing)
          ? ((_patchMap[Deal$.listing] is Function)
                    ? _patchMap[Deal$.listing](this.listing)
                    : (_patchMap[Deal$.listing] is Patch)
                    ? _patchMap[Deal$.listing].applyTo(this.listing)
                    : _patchMap[Deal$.listing])
                as Listing
          : this.listing,
      badges: _patchMap.containsKey(Deal$.badges)
          ? ((_patchMap[Deal$.badges] is Function)
                    ? _patchMap[Deal$.badges](this.badges)
                    : (_patchMap[Deal$.badges] is Patch)
                    ? _patchMap[Deal$.badges].applyTo(this.badges)
                    : _patchMap[Deal$.badges])
                as List<String>?
          : this.badges,
      discountRate: _patchMap.containsKey(Deal$.discountRate)
          ? ((_patchMap[Deal$.discountRate] is Function)
                    ? _patchMap[Deal$.discountRate](this.discountRate)
                    : (_patchMap[Deal$.discountRate] is Patch)
                    ? _patchMap[Deal$.discountRate].applyTo(this.discountRate)
                    : _patchMap[Deal$.discountRate])
                as double?
          : this.discountRate,
      likeCount: _patchMap.containsKey(Deal$.likeCount)
          ? ((_patchMap[Deal$.likeCount] is Function)
                    ? _patchMap[Deal$.likeCount](this.likeCount)
                    : (_patchMap[Deal$.likeCount] is Patch)
                    ? _patchMap[Deal$.likeCount].applyTo(this.likeCount)
                    : _patchMap[Deal$.likeCount])
                as int
          : this.likeCount,
      dislikeCount: _patchMap.containsKey(Deal$.dislikeCount)
          ? ((_patchMap[Deal$.dislikeCount] is Function)
                    ? _patchMap[Deal$.dislikeCount](this.dislikeCount)
                    : (_patchMap[Deal$.dislikeCount] is Patch)
                    ? _patchMap[Deal$.dislikeCount].applyTo(this.dislikeCount)
                    : _patchMap[Deal$.dislikeCount])
                as int
          : this.dislikeCount,
      shareCount: _patchMap.containsKey(Deal$.shareCount)
          ? ((_patchMap[Deal$.shareCount] is Function)
                    ? _patchMap[Deal$.shareCount](this.shareCount)
                    : (_patchMap[Deal$.shareCount] is Patch)
                    ? _patchMap[Deal$.shareCount].applyTo(this.shareCount)
                    : _patchMap[Deal$.shareCount])
                as int
          : this.shareCount,
      manLikeCount: _patchMap.containsKey(Deal$.manLikeCount)
          ? ((_patchMap[Deal$.manLikeCount] is Function)
                    ? _patchMap[Deal$.manLikeCount](this.manLikeCount)
                    : (_patchMap[Deal$.manLikeCount] is Patch)
                    ? _patchMap[Deal$.manLikeCount].applyTo(this.manLikeCount)
                    : _patchMap[Deal$.manLikeCount])
                as int
          : this.manLikeCount,
      womanLikeCount: _patchMap.containsKey(Deal$.womanLikeCount)
          ? ((_patchMap[Deal$.womanLikeCount] is Function)
                    ? _patchMap[Deal$.womanLikeCount](this.womanLikeCount)
                    : (_patchMap[Deal$.womanLikeCount] is Patch)
                    ? _patchMap[Deal$.womanLikeCount].applyTo(
                        this.womanLikeCount,
                      )
                    : _patchMap[Deal$.womanLikeCount])
                as int
          : this.womanLikeCount,
      manDislikeCount: _patchMap.containsKey(Deal$.manDislikeCount)
          ? ((_patchMap[Deal$.manDislikeCount] is Function)
                    ? _patchMap[Deal$.manDislikeCount](this.manDislikeCount)
                    : (_patchMap[Deal$.manDislikeCount] is Patch)
                    ? _patchMap[Deal$.manDislikeCount].applyTo(
                        this.manDislikeCount,
                      )
                    : _patchMap[Deal$.manDislikeCount])
                as int
          : this.manDislikeCount,
      womanDislikeCount: _patchMap.containsKey(Deal$.womanDislikeCount)
          ? ((_patchMap[Deal$.womanDislikeCount] is Function)
                    ? _patchMap[Deal$.womanDislikeCount](this.womanDislikeCount)
                    : (_patchMap[Deal$.womanDislikeCount] is Patch)
                    ? _patchMap[Deal$.womanDislikeCount].applyTo(
                        this.womanDislikeCount,
                      )
                    : _patchMap[Deal$.womanDislikeCount])
                as int
          : this.womanDislikeCount,
      ratingScore: _patchMap.containsKey(Deal$.ratingScore)
          ? ((_patchMap[Deal$.ratingScore] is Function)
                    ? _patchMap[Deal$.ratingScore](this.ratingScore)
                    : (_patchMap[Deal$.ratingScore] is Patch)
                    ? _patchMap[Deal$.ratingScore].applyTo(this.ratingScore)
                    : _patchMap[Deal$.ratingScore])
                as double?
          : this.ratingScore,
      reviewCount: _patchMap.containsKey(Deal$.reviewCount)
          ? ((_patchMap[Deal$.reviewCount] is Function)
                    ? _patchMap[Deal$.reviewCount](this.reviewCount)
                    : (_patchMap[Deal$.reviewCount] is Patch)
                    ? _patchMap[Deal$.reviewCount].applyTo(this.reviewCount)
                    : _patchMap[Deal$.reviewCount])
                as int?
          : this.reviewCount,
      aiReasoning: _patchMap.containsKey(Deal$.aiReasoning)
          ? ((_patchMap[Deal$.aiReasoning] is Function)
                    ? _patchMap[Deal$.aiReasoning](this.aiReasoning)
                    : (_patchMap[Deal$.aiReasoning] is Patch)
                    ? _patchMap[Deal$.aiReasoning].applyTo(this.aiReasoning)
                    : _patchMap[Deal$.aiReasoning])
                as String?
          : this.aiReasoning,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deal &&
        id == other.id &&
        listing == other.listing &&
        badges == other.badges &&
        discountRate == other.discountRate &&
        likeCount == other.likeCount &&
        dislikeCount == other.dislikeCount &&
        shareCount == other.shareCount &&
        manLikeCount == other.manLikeCount &&
        womanLikeCount == other.womanLikeCount &&
        manDislikeCount == other.manDislikeCount &&
        womanDislikeCount == other.womanDislikeCount &&
        ratingScore == other.ratingScore &&
        reviewCount == other.reviewCount &&
        aiReasoning == other.aiReasoning;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.listing,
      this.badges,
      this.discountRate,
      this.likeCount,
      this.dislikeCount,
      this.shareCount,
      this.manLikeCount,
      this.womanLikeCount,
      this.manDislikeCount,
      this.womanDislikeCount,
      this.ratingScore,
      this.reviewCount,
      this.aiReasoning,
    );
  }

  @override
  String toString() {
    return 'Deal(' +
        'id: ${id}' +
        ', ' +
        'listing: ${listing}' +
        ', ' +
        'badges: ${badges}' +
        ', ' +
        'discountRate: ${discountRate}' +
        ', ' +
        'likeCount: ${likeCount}' +
        ', ' +
        'dislikeCount: ${dislikeCount}' +
        ', ' +
        'shareCount: ${shareCount}' +
        ', ' +
        'manLikeCount: ${manLikeCount}' +
        ', ' +
        'womanLikeCount: ${womanLikeCount}' +
        ', ' +
        'manDislikeCount: ${manDislikeCount}' +
        ', ' +
        'womanDislikeCount: ${womanDislikeCount}' +
        ', ' +
        'ratingScore: ${ratingScore}' +
        ', ' +
        'reviewCount: ${reviewCount}' +
        ', ' +
        'aiReasoning: ${aiReasoning})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$DealToJson(this);
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

extension DealPropertyHelpers on Deal {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
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

  bool get hasDiscountRate {
    return this.discountRate != null;
  }

  bool get noDiscountRate {
    return this.discountRate == null;
  }

  double get discountRateRequired {
    return this.discountRate ??
        (throw StateError('discountRate is required but was null'));
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

  bool get hasAiReasoning {
    return this.aiReasoning?.isNotEmpty == true;
  }

  bool get noAiReasoning {
    return this.aiReasoning?.isEmpty ?? true;
  }

  String get aiReasoningRequired {
    return this.aiReasoning ??
        (throw StateError('aiReasoning is required but was null'));
  }
}

extension DealSerialization on Deal {
  Map<String, dynamic> toJson() {
    return _$DealToJson(this);
  }
}

enum Deal$ {
  id,
  listing,
  badges,
  discountRate,
  likeCount,
  dislikeCount,
  shareCount,
  manLikeCount,
  womanLikeCount,
  manDislikeCount,
  womanDislikeCount,
  ratingScore,
  reviewCount,
  aiReasoning,
}

class DealPatch extends PatchBase<Deal, Deal$> {
  Deal applyTo(Deal entity) {
    return entity.patchWithDeal(this);
  }

  DealPatch withId(String? value) {
    patchMap[Deal$.id] = value;
    return this;
  }

  DealPatch withListing(Listing? value) {
    patchMap[Deal$.listing] = value;
    return this;
  }

  DealPatch withListingPatch(ListingPatch patch) {
    patchMap[Deal$.listing] = patch;
    return this;
  }

  DealPatch withListingPatchFunc(ListingPatch Function(ListingPatch) patch) {
    patchMap[Deal$.listing] = (dynamic current) {
      var currentPatch = ListingPatch();
      return patch(currentPatch).applyTo(current as Listing);
    };
    return this;
  }

  DealPatch withBadges(List<String>? value) {
    patchMap[Deal$.badges] = value;
    return this;
  }

  DealPatch withDiscountRate(double? value) {
    patchMap[Deal$.discountRate] = value;
    return this;
  }

  DealPatch withLikeCount(int? value) {
    patchMap[Deal$.likeCount] = value;
    return this;
  }

  DealPatch withDislikeCount(int? value) {
    patchMap[Deal$.dislikeCount] = value;
    return this;
  }

  DealPatch withShareCount(int? value) {
    patchMap[Deal$.shareCount] = value;
    return this;
  }

  DealPatch withManLikeCount(int? value) {
    patchMap[Deal$.manLikeCount] = value;
    return this;
  }

  DealPatch withWomanLikeCount(int? value) {
    patchMap[Deal$.womanLikeCount] = value;
    return this;
  }

  DealPatch withManDislikeCount(int? value) {
    patchMap[Deal$.manDislikeCount] = value;
    return this;
  }

  DealPatch withWomanDislikeCount(int? value) {
    patchMap[Deal$.womanDislikeCount] = value;
    return this;
  }

  DealPatch withRatingScore(double? value) {
    patchMap[Deal$.ratingScore] = value;
    return this;
  }

  DealPatch withReviewCount(int? value) {
    patchMap[Deal$.reviewCount] = value;
    return this;
  }

  DealPatch withAiReasoning(String? value) {
    patchMap[Deal$.aiReasoning] = value;
    return this;
  }
}

/// Field descriptors for [Deal] query construction
abstract final class DealFields {
  static const id = Field<Deal, String>('id', _$id);

  static const listing = Field<Deal, Listing>('listing', _$listing);

  static const badges = Field<Deal, List<String>?>('badges', _$badges);

  static const discountRate = Field<Deal, double?>(
    'discountRate',
    _$discountRate,
  );

  static const likeCount = Field<Deal, int>('likeCount', _$likeCount);

  static const dislikeCount = Field<Deal, int>('dislikeCount', _$dislikeCount);

  static const shareCount = Field<Deal, int>('shareCount', _$shareCount);

  static const manLikeCount = Field<Deal, int>('manLikeCount', _$manLikeCount);

  static const womanLikeCount = Field<Deal, int>(
    'womanLikeCount',
    _$womanLikeCount,
  );

  static const manDislikeCount = Field<Deal, int>(
    'manDislikeCount',
    _$manDislikeCount,
  );

  static const womanDislikeCount = Field<Deal, int>(
    'womanDislikeCount',
    _$womanDislikeCount,
  );

  static const ratingScore = Field<Deal, double?>('ratingScore', _$ratingScore);

  static const reviewCount = Field<Deal, int?>('reviewCount', _$reviewCount);

  static const aiReasoning = Field<Deal, String?>('aiReasoning', _$aiReasoning);

  static String _$id(Deal e) {
    return e.id;
  }

  static Listing _$listing(Deal e) {
    return e.listing;
  }

  static List<String>? _$badges(Deal e) {
    return e.badges;
  }

  static double? _$discountRate(Deal e) {
    return e.discountRate;
  }

  static int _$likeCount(Deal e) {
    return e.likeCount;
  }

  static int _$dislikeCount(Deal e) {
    return e.dislikeCount;
  }

  static int _$shareCount(Deal e) {
    return e.shareCount;
  }

  static int _$manLikeCount(Deal e) {
    return e.manLikeCount;
  }

  static int _$womanLikeCount(Deal e) {
    return e.womanLikeCount;
  }

  static int _$manDislikeCount(Deal e) {
    return e.manDislikeCount;
  }

  static int _$womanDislikeCount(Deal e) {
    return e.womanDislikeCount;
  }

  static double? _$ratingScore(Deal e) {
    return e.ratingScore;
  }

  static int? _$reviewCount(Deal e) {
    return e.reviewCount;
  }

  static String? _$aiReasoning(Deal e) {
    return e.aiReasoning;
  }
}

extension DealCompareE on Deal {
  Map<String, dynamic> compareToDeal(Deal other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (listing != other.listing) {
      diff['listing'] = () => other.listing;
    }

    if (badges != other.badges) {
      diff['badges'] = () => other.badges;
    }

    if (discountRate != other.discountRate) {
      diff['discountRate'] = () => other.discountRate;
    }

    if (likeCount != other.likeCount) {
      diff['likeCount'] = () => other.likeCount;
    }

    if (dislikeCount != other.dislikeCount) {
      diff['dislikeCount'] = () => other.dislikeCount;
    }

    if (shareCount != other.shareCount) {
      diff['shareCount'] = () => other.shareCount;
    }

    if (manLikeCount != other.manLikeCount) {
      diff['manLikeCount'] = () => other.manLikeCount;
    }

    if (womanLikeCount != other.womanLikeCount) {
      diff['womanLikeCount'] = () => other.womanLikeCount;
    }

    if (manDislikeCount != other.manDislikeCount) {
      diff['manDislikeCount'] = () => other.manDislikeCount;
    }

    if (womanDislikeCount != other.womanDislikeCount) {
      diff['womanDislikeCount'] = () => other.womanDislikeCount;
    }

    if (ratingScore != other.ratingScore) {
      diff['ratingScore'] = () => other.ratingScore;
    }

    if (reviewCount != other.reviewCount) {
      diff['reviewCount'] = () => other.reviewCount;
    }

    if (aiReasoning != other.aiReasoning) {
      diff['aiReasoning'] = () => other.aiReasoning;
    }
    return diff;
  }
}
