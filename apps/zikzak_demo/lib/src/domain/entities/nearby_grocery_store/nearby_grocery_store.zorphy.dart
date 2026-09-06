// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'nearby_grocery_store.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class NearbyGroceryStore {
  NearbyGroceryStore({
    required String this.id,
    required String this.name,
    String? this.logoUrl,
    required double this.distance,
    double? this.latitude,
    double? this.longitude,
  });

  factory NearbyGroceryStore.fromJson(Map<String, dynamic> json) =>
      _$NearbyGroceryStoreFromJson(json);

  final String id;

  final String name;

  final String? logoUrl;

  final double distance;

  final double? latitude;

  final double? longitude;

  NearbyGroceryStore copyWith({
    String? id,
    String? name,
    String? logoUrl,
    double? distance,
    double? latitude,
    double? longitude,
  }) {
    return NearbyGroceryStore(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  NearbyGroceryStore copyWithField<T>(
    Field<NearbyGroceryStore, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'name':
        return copyWith(name: value as String);
      case 'logoUrl':
        return copyWith(logoUrl: value as String?);
      case 'distance':
        return copyWith(distance: value as double);
      case 'latitude':
        return copyWith(latitude: value as double?);
      case 'longitude':
        return copyWith(longitude: value as double?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'NearbyGroceryStore has no settable field with this name',
        );
    }
  }

  NearbyGroceryStore copyWithNearbyGroceryStore({
    String? id,
    String? name,
    String? logoUrl,
    double? distance,
    double? latitude,
    double? longitude,
  }) {
    return copyWith(
      id: id,
      name: name,
      logoUrl: logoUrl,
      distance: distance,
      latitude: latitude,
      longitude: longitude,
    );
  }

  NearbyGroceryStore patchWithNearbyGroceryStore([
    NearbyGroceryStorePatch? patchInput,
  ]) {
    final _patcher = patchInput ?? NearbyGroceryStorePatch();
    final _patchMap = _patcher.patchMap;
    return NearbyGroceryStore(
      id: _patchMap.containsKey(NearbyGroceryStore$.id)
          ? ((_patchMap[NearbyGroceryStore$.id] is Function)
                    ? _patchMap[NearbyGroceryStore$.id](this.id)
                    : (_patchMap[NearbyGroceryStore$.id] is Patch)
                    ? _patchMap[NearbyGroceryStore$.id].applyTo(this.id)
                    : _patchMap[NearbyGroceryStore$.id])
                as String
          : this.id,
      name: _patchMap.containsKey(NearbyGroceryStore$.name_)
          ? ((_patchMap[NearbyGroceryStore$.name_] is Function)
                    ? _patchMap[NearbyGroceryStore$.name_](this.name)
                    : (_patchMap[NearbyGroceryStore$.name_] is Patch)
                    ? _patchMap[NearbyGroceryStore$.name_].applyTo(this.name)
                    : _patchMap[NearbyGroceryStore$.name_])
                as String
          : this.name,
      logoUrl: _patchMap.containsKey(NearbyGroceryStore$.logoUrl)
          ? ((_patchMap[NearbyGroceryStore$.logoUrl] is Function)
                    ? _patchMap[NearbyGroceryStore$.logoUrl](this.logoUrl)
                    : (_patchMap[NearbyGroceryStore$.logoUrl] is Patch)
                    ? _patchMap[NearbyGroceryStore$.logoUrl].applyTo(
                        this.logoUrl,
                      )
                    : _patchMap[NearbyGroceryStore$.logoUrl])
                as String?
          : this.logoUrl,
      distance: _patchMap.containsKey(NearbyGroceryStore$.distance)
          ? ((_patchMap[NearbyGroceryStore$.distance] is Function)
                    ? _patchMap[NearbyGroceryStore$.distance](this.distance)
                    : (_patchMap[NearbyGroceryStore$.distance] is Patch)
                    ? _patchMap[NearbyGroceryStore$.distance].applyTo(
                        this.distance,
                      )
                    : _patchMap[NearbyGroceryStore$.distance])
                as double
          : this.distance,
      latitude: _patchMap.containsKey(NearbyGroceryStore$.latitude)
          ? ((_patchMap[NearbyGroceryStore$.latitude] is Function)
                    ? _patchMap[NearbyGroceryStore$.latitude](this.latitude)
                    : (_patchMap[NearbyGroceryStore$.latitude] is Patch)
                    ? _patchMap[NearbyGroceryStore$.latitude].applyTo(
                        this.latitude,
                      )
                    : _patchMap[NearbyGroceryStore$.latitude])
                as double?
          : this.latitude,
      longitude: _patchMap.containsKey(NearbyGroceryStore$.longitude)
          ? ((_patchMap[NearbyGroceryStore$.longitude] is Function)
                    ? _patchMap[NearbyGroceryStore$.longitude](this.longitude)
                    : (_patchMap[NearbyGroceryStore$.longitude] is Patch)
                    ? _patchMap[NearbyGroceryStore$.longitude].applyTo(
                        this.longitude,
                      )
                    : _patchMap[NearbyGroceryStore$.longitude])
                as double?
          : this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NearbyGroceryStore &&
        id == other.id &&
        name == other.name &&
        logoUrl == other.logoUrl &&
        distance == other.distance &&
        latitude == other.latitude &&
        longitude == other.longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.name,
      this.logoUrl,
      this.distance,
      this.latitude,
      this.longitude,
    );
  }

  @override
  String toString() {
    return 'NearbyGroceryStore(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'logoUrl: ${logoUrl}' +
        ', ' +
        'distance: ${distance}' +
        ', ' +
        'latitude: ${latitude}' +
        ', ' +
        'longitude: ${longitude})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$NearbyGroceryStoreToJson(this);
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

extension NearbyGroceryStorePropertyHelpers on NearbyGroceryStore {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasName {
    return this.name.isNotEmpty;
  }

  bool get noName {
    return this.name.isEmpty;
  }

  bool get hasLogoUrl {
    return this.logoUrl?.isNotEmpty == true;
  }

  bool get noLogoUrl {
    return this.logoUrl?.isEmpty ?? true;
  }

  String get logoUrlRequired {
    return this.logoUrl ??
        (throw StateError('logoUrl is required but was null'));
  }

  bool get hasLatitude {
    return this.latitude != null;
  }

  bool get noLatitude {
    return this.latitude == null;
  }

  double get latitudeRequired {
    return this.latitude ??
        (throw StateError('latitude is required but was null'));
  }

  bool get hasLongitude {
    return this.longitude != null;
  }

  bool get noLongitude {
    return this.longitude == null;
  }

  double get longitudeRequired {
    return this.longitude ??
        (throw StateError('longitude is required but was null'));
  }
}

extension NearbyGroceryStoreSerialization on NearbyGroceryStore {
  Map<String, dynamic> toJson() {
    return _$NearbyGroceryStoreToJson(this);
  }
}

enum NearbyGroceryStore$ { id, name_, logoUrl, distance, latitude, longitude }

class NearbyGroceryStorePatch
    extends PatchBase<NearbyGroceryStore, NearbyGroceryStore$> {
  NearbyGroceryStore applyTo(NearbyGroceryStore entity) {
    return entity.patchWithNearbyGroceryStore(this);
  }

  NearbyGroceryStorePatch withId(String? value) {
    patchMap[NearbyGroceryStore$.id] = value;
    return this;
  }

  NearbyGroceryStorePatch withName(String? value) {
    patchMap[NearbyGroceryStore$.name_] = value;
    return this;
  }

  NearbyGroceryStorePatch withLogoUrl(String? value) {
    patchMap[NearbyGroceryStore$.logoUrl] = value;
    return this;
  }

  NearbyGroceryStorePatch withDistance(double? value) {
    patchMap[NearbyGroceryStore$.distance] = value;
    return this;
  }

  NearbyGroceryStorePatch withLatitude(double? value) {
    patchMap[NearbyGroceryStore$.latitude] = value;
    return this;
  }

  NearbyGroceryStorePatch withLongitude(double? value) {
    patchMap[NearbyGroceryStore$.longitude] = value;
    return this;
  }
}

/// Field descriptors for [NearbyGroceryStore] query construction
abstract final class NearbyGroceryStoreFields {
  static const id = Field<NearbyGroceryStore, String>('id', _$id);

  static const name = Field<NearbyGroceryStore, String>('name', _$name);

  static const logoUrl = Field<NearbyGroceryStore, String?>(
    'logoUrl',
    _$logoUrl,
  );

  static const distance = Field<NearbyGroceryStore, double>(
    'distance',
    _$distance,
  );

  static const latitude = Field<NearbyGroceryStore, double?>(
    'latitude',
    _$latitude,
  );

  static const longitude = Field<NearbyGroceryStore, double?>(
    'longitude',
    _$longitude,
  );

  static String _$id(NearbyGroceryStore e) {
    return e.id;
  }

  static String _$name(NearbyGroceryStore e) {
    return e.name;
  }

  static String? _$logoUrl(NearbyGroceryStore e) {
    return e.logoUrl;
  }

  static double _$distance(NearbyGroceryStore e) {
    return e.distance;
  }

  static double? _$latitude(NearbyGroceryStore e) {
    return e.latitude;
  }

  static double? _$longitude(NearbyGroceryStore e) {
    return e.longitude;
  }
}

extension NearbyGroceryStoreCompareE on NearbyGroceryStore {
  Map<String, dynamic> compareToNearbyGroceryStore(NearbyGroceryStore other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (logoUrl != other.logoUrl) {
      diff['logoUrl'] = () => other.logoUrl;
    }

    if (distance != other.distance) {
      diff['distance'] = () => other.distance;
    }

    if (latitude != other.latitude) {
      diff['latitude'] = () => other.latitude;
    }

    if (longitude != other.longitude) {
      diff['longitude'] = () => other.longitude;
    }
    return diff;
  }
}
