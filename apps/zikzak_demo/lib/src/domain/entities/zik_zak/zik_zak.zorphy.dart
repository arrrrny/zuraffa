// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'zik_zak.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ZikZak {
  ZikZak({
    String? id,
    required TextSpark this.spark,
    required Listing this.listing,
    required ZikZakOrigin this.origin,
    required DateTime this.createdAt,
  }) : this.id = id ?? const Uuid().v4();

  factory ZikZak.fromJson(Map<String, dynamic> json) => _$ZikZakFromJson(json);

  final String id;

  final TextSpark spark;

  final Listing listing;

  final ZikZakOrigin origin;

  final DateTime createdAt;

  ZikZak copyWith({
    String? id,
    TextSpark? spark,
    Listing? listing,
    ZikZakOrigin? origin,
    DateTime? createdAt,
  }) {
    return ZikZak(
      id: id ?? this.id,
      spark: spark ?? this.spark,
      listing: listing ?? this.listing,
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ZikZak copyWithField<T>(Field<ZikZak, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'spark':
        return copyWith(spark: value as TextSpark);
      case 'listing':
        return copyWith(listing: value as Listing);
      case 'origin':
        return copyWith(origin: value as ZikZakOrigin);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ZikZak has no settable field with this name',
        );
    }
  }

  ZikZak copyWithZikZak({
    String? id,
    TextSpark? spark,
    Listing? listing,
    ZikZakOrigin? origin,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      spark: spark,
      listing: listing,
      origin: origin,
      createdAt: createdAt,
    );
  }

  ZikZak patchWithZikZak([ZikZakPatch? patchInput]) {
    final _patcher = patchInput ?? ZikZakPatch();
    final _patchMap = _patcher.patchMap;
    return ZikZak(
      id: _patchMap.containsKey(ZikZak$.id)
          ? ((_patchMap[ZikZak$.id] is Function)
                    ? _patchMap[ZikZak$.id](this.id)
                    : (_patchMap[ZikZak$.id] is Patch)
                    ? _patchMap[ZikZak$.id].applyTo(this.id)
                    : _patchMap[ZikZak$.id])
                as String
          : this.id,
      spark: _patchMap.containsKey(ZikZak$.spark)
          ? ((_patchMap[ZikZak$.spark] is Function)
                    ? _patchMap[ZikZak$.spark](this.spark)
                    : (_patchMap[ZikZak$.spark] is Patch)
                    ? _patchMap[ZikZak$.spark].applyTo(this.spark)
                    : _patchMap[ZikZak$.spark])
                as TextSpark
          : this.spark,
      listing: _patchMap.containsKey(ZikZak$.listing)
          ? ((_patchMap[ZikZak$.listing] is Function)
                    ? _patchMap[ZikZak$.listing](this.listing)
                    : (_patchMap[ZikZak$.listing] is Patch)
                    ? _patchMap[ZikZak$.listing].applyTo(this.listing)
                    : _patchMap[ZikZak$.listing])
                as Listing
          : this.listing,
      origin: _patchMap.containsKey(ZikZak$.origin)
          ? ((_patchMap[ZikZak$.origin] is Function)
                    ? _patchMap[ZikZak$.origin](this.origin)
                    : (_patchMap[ZikZak$.origin] is Patch)
                    ? _patchMap[ZikZak$.origin].applyTo(this.origin)
                    : _patchMap[ZikZak$.origin])
                as ZikZakOrigin
          : this.origin,
      createdAt: _patchMap.containsKey(ZikZak$.createdAt)
          ? ((_patchMap[ZikZak$.createdAt] is Function)
                    ? _patchMap[ZikZak$.createdAt](this.createdAt)
                    : (_patchMap[ZikZak$.createdAt] is Patch)
                    ? _patchMap[ZikZak$.createdAt].applyTo(this.createdAt)
                    : _patchMap[ZikZak$.createdAt])
                as DateTime
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZikZak &&
        id == other.id &&
        spark == other.spark &&
        listing == other.listing &&
        origin == other.origin &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.spark,
      this.listing,
      this.origin,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ZikZak(' +
        'id: ${id}' +
        ', ' +
        'spark: ${spark}' +
        ', ' +
        'listing: ${listing}' +
        ', ' +
        'origin: ${origin}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is ZikZak &&
        spark == other.spark &&
        listing == other.listing &&
        origin == other.origin &&
        createdAt == other.createdAt;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$ZikZakToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ZikZakToJson(this);
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

extension ZikZakPropertyHelpers on ZikZak {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get isOriginBarcode {
    return this.origin == ZikZakOrigin.barcode;
  }

  bool get isOriginUrl {
    return this.origin == ZikZakOrigin.url;
  }

  bool get isOriginText {
    return this.origin == ZikZakOrigin.text;
  }

  bool get isOriginShare {
    return this.origin == ZikZakOrigin.share;
  }
}

extension ZikZakSerialization on ZikZak {
  Map<String, dynamic> toJson() {
    return _$ZikZakToJson(this);
  }
}

enum ZikZak$ { id, spark, listing, origin, createdAt }

class ZikZakPatch extends PatchBase<ZikZak, ZikZak$> {
  ZikZak applyTo(ZikZak entity) {
    return entity.patchWithZikZak(this);
  }

  ZikZakPatch withId(String? value) {
    patchMap[ZikZak$.id] = value;
    return this;
  }

  ZikZakPatch withSpark(TextSpark? value) {
    patchMap[ZikZak$.spark] = value;
    return this;
  }

  ZikZakPatch withSparkPatch(TextSparkPatch patch) {
    patchMap[ZikZak$.spark] = patch;
    return this;
  }

  ZikZakPatch withSparkPatchFunc(
    TextSparkPatch Function(TextSparkPatch) patch,
  ) {
    patchMap[ZikZak$.spark] = (dynamic current) {
      var currentPatch = TextSparkPatch();
      return patch(currentPatch).applyTo(current as TextSpark);
    };
    return this;
  }

  ZikZakPatch withListing(Listing? value) {
    patchMap[ZikZak$.listing] = value;
    return this;
  }

  ZikZakPatch withListingPatch(ListingPatch patch) {
    patchMap[ZikZak$.listing] = patch;
    return this;
  }

  ZikZakPatch withListingPatchFunc(ListingPatch Function(ListingPatch) patch) {
    patchMap[ZikZak$.listing] = (dynamic current) {
      var currentPatch = ListingPatch();
      return patch(currentPatch).applyTo(current as Listing);
    };
    return this;
  }

  ZikZakPatch withOrigin(ZikZakOrigin? value) {
    patchMap[ZikZak$.origin] = value;
    return this;
  }

  ZikZakPatch withCreatedAt(DateTime? value) {
    patchMap[ZikZak$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [ZikZak] query construction
abstract final class ZikZakFields {
  static const id = Field<ZikZak, String>('id', _$id);

  static const spark = Field<ZikZak, TextSpark>('spark', _$spark);

  static const listing = Field<ZikZak, Listing>('listing', _$listing);

  static const origin = Field<ZikZak, ZikZakOrigin>('origin', _$origin);

  static const createdAt = Field<ZikZak, DateTime>('createdAt', _$createdAt);

  static String _$id(ZikZak e) {
    return e.id;
  }

  static TextSpark _$spark(ZikZak e) {
    return e.spark;
  }

  static Listing _$listing(ZikZak e) {
    return e.listing;
  }

  static ZikZakOrigin _$origin(ZikZak e) {
    return e.origin;
  }

  static DateTime _$createdAt(ZikZak e) {
    return e.createdAt;
  }
}

extension ZikZakCompareE on ZikZak {
  Map<String, dynamic> compareToZikZak(ZikZak other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (spark != other.spark) {
      diff['spark'] = () => other.spark;
    }

    if (listing != other.listing) {
      diff['listing'] = () => other.listing;
    }

    if (origin != other.origin) {
      diff['origin'] = () => other.origin;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
