// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_store.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GroceryStore {
  GroceryStore({
    required String this.id,
    required String this.name,
    required String this.marketName,
    required double this.latitude,
    required double this.longitude,
    required double this.distance,
    required bool this.isSelected,
  });

  factory GroceryStore.fromJson(Map<String, dynamic> json) =>
      _$GroceryStoreFromJson(json);

  final String id;

  final String name;

  final String marketName;

  final double latitude;

  final double longitude;

  final double distance;

  final bool isSelected;

  GroceryStore copyWith({
    String? id,
    String? name,
    String? marketName,
    double? latitude,
    double? longitude,
    double? distance,
    bool? isSelected,
  }) {
    return GroceryStore(
      id: id ?? this.id,
      name: name ?? this.name,
      marketName: marketName ?? this.marketName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GroceryStore copyWithField<T>(Field<GroceryStore, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'name':
        return copyWith(name: value as String);
      case 'marketName':
        return copyWith(marketName: value as String);
      case 'latitude':
        return copyWith(latitude: value as double);
      case 'longitude':
        return copyWith(longitude: value as double);
      case 'distance':
        return copyWith(distance: value as double);
      case 'isSelected':
        return copyWith(isSelected: value as bool);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GroceryStore has no settable field with this name',
        );
    }
  }

  GroceryStore copyWithGroceryStore({
    String? id,
    String? name,
    String? marketName,
    double? latitude,
    double? longitude,
    double? distance,
    bool? isSelected,
  }) {
    return copyWith(
      id: id,
      name: name,
      marketName: marketName,
      latitude: latitude,
      longitude: longitude,
      distance: distance,
      isSelected: isSelected,
    );
  }

  GroceryStore patchWithGroceryStore([GroceryStorePatch? patchInput]) {
    final _patcher = patchInput ?? GroceryStorePatch();
    final _patchMap = _patcher.patchMap;
    return GroceryStore(
      id: _patchMap.containsKey(GroceryStore$.id)
          ? ((_patchMap[GroceryStore$.id] is Function)
                    ? _patchMap[GroceryStore$.id](this.id)
                    : (_patchMap[GroceryStore$.id] is Patch)
                    ? _patchMap[GroceryStore$.id].applyTo(this.id)
                    : _patchMap[GroceryStore$.id])
                as String
          : this.id,
      name: _patchMap.containsKey(GroceryStore$.name_)
          ? ((_patchMap[GroceryStore$.name_] is Function)
                    ? _patchMap[GroceryStore$.name_](this.name)
                    : (_patchMap[GroceryStore$.name_] is Patch)
                    ? _patchMap[GroceryStore$.name_].applyTo(this.name)
                    : _patchMap[GroceryStore$.name_])
                as String
          : this.name,
      marketName: _patchMap.containsKey(GroceryStore$.marketName)
          ? ((_patchMap[GroceryStore$.marketName] is Function)
                    ? _patchMap[GroceryStore$.marketName](this.marketName)
                    : (_patchMap[GroceryStore$.marketName] is Patch)
                    ? _patchMap[GroceryStore$.marketName].applyTo(
                        this.marketName,
                      )
                    : _patchMap[GroceryStore$.marketName])
                as String
          : this.marketName,
      latitude: _patchMap.containsKey(GroceryStore$.latitude)
          ? ((_patchMap[GroceryStore$.latitude] is Function)
                    ? _patchMap[GroceryStore$.latitude](this.latitude)
                    : (_patchMap[GroceryStore$.latitude] is Patch)
                    ? _patchMap[GroceryStore$.latitude].applyTo(this.latitude)
                    : _patchMap[GroceryStore$.latitude])
                as double
          : this.latitude,
      longitude: _patchMap.containsKey(GroceryStore$.longitude)
          ? ((_patchMap[GroceryStore$.longitude] is Function)
                    ? _patchMap[GroceryStore$.longitude](this.longitude)
                    : (_patchMap[GroceryStore$.longitude] is Patch)
                    ? _patchMap[GroceryStore$.longitude].applyTo(this.longitude)
                    : _patchMap[GroceryStore$.longitude])
                as double
          : this.longitude,
      distance: _patchMap.containsKey(GroceryStore$.distance)
          ? ((_patchMap[GroceryStore$.distance] is Function)
                    ? _patchMap[GroceryStore$.distance](this.distance)
                    : (_patchMap[GroceryStore$.distance] is Patch)
                    ? _patchMap[GroceryStore$.distance].applyTo(this.distance)
                    : _patchMap[GroceryStore$.distance])
                as double
          : this.distance,
      isSelected: _patchMap.containsKey(GroceryStore$.isSelected)
          ? ((_patchMap[GroceryStore$.isSelected] is Function)
                    ? _patchMap[GroceryStore$.isSelected](this.isSelected)
                    : (_patchMap[GroceryStore$.isSelected] is Patch)
                    ? _patchMap[GroceryStore$.isSelected].applyTo(
                        this.isSelected,
                      )
                    : _patchMap[GroceryStore$.isSelected])
                as bool
          : this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryStore &&
        id == other.id &&
        name == other.name &&
        marketName == other.marketName &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        distance == other.distance &&
        isSelected == other.isSelected;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.name,
      this.marketName,
      this.latitude,
      this.longitude,
      this.distance,
      this.isSelected,
    );
  }

  @override
  String toString() {
    return 'GroceryStore(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'marketName: ${marketName}' +
        ', ' +
        'latitude: ${latitude}' +
        ', ' +
        'longitude: ${longitude}' +
        ', ' +
        'distance: ${distance}' +
        ', ' +
        'isSelected: ${isSelected})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GroceryStoreToJson(this);
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

extension GroceryStorePropertyHelpers on GroceryStore {
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

  bool get hasMarketName {
    return this.marketName.isNotEmpty;
  }

  bool get noMarketName {
    return this.marketName.isEmpty;
  }
}

extension GroceryStoreSerialization on GroceryStore {
  Map<String, dynamic> toJson() {
    return _$GroceryStoreToJson(this);
  }
}

enum GroceryStore$ {
  id,
  name_,
  marketName,
  latitude,
  longitude,
  distance,
  isSelected,
}

class GroceryStorePatch extends PatchBase<GroceryStore, GroceryStore$> {
  GroceryStore applyTo(GroceryStore entity) {
    return entity.patchWithGroceryStore(this);
  }

  GroceryStorePatch withId(String? value) {
    patchMap[GroceryStore$.id] = value;
    return this;
  }

  GroceryStorePatch withName(String? value) {
    patchMap[GroceryStore$.name_] = value;
    return this;
  }

  GroceryStorePatch withMarketName(String? value) {
    patchMap[GroceryStore$.marketName] = value;
    return this;
  }

  GroceryStorePatch withLatitude(double? value) {
    patchMap[GroceryStore$.latitude] = value;
    return this;
  }

  GroceryStorePatch withLongitude(double? value) {
    patchMap[GroceryStore$.longitude] = value;
    return this;
  }

  GroceryStorePatch withDistance(double? value) {
    patchMap[GroceryStore$.distance] = value;
    return this;
  }

  GroceryStorePatch withIsSelected(bool? value) {
    patchMap[GroceryStore$.isSelected] = value;
    return this;
  }
}

/// Field descriptors for [GroceryStore] query construction
abstract final class GroceryStoreFields {
  static const id = Field<GroceryStore, String>('id', _$id);

  static const name = Field<GroceryStore, String>('name', _$name);

  static const marketName = Field<GroceryStore, String>(
    'marketName',
    _$marketName,
  );

  static const latitude = Field<GroceryStore, double>('latitude', _$latitude);

  static const longitude = Field<GroceryStore, double>(
    'longitude',
    _$longitude,
  );

  static const distance = Field<GroceryStore, double>('distance', _$distance);

  static const isSelected = Field<GroceryStore, bool>(
    'isSelected',
    _$isSelected,
  );

  static String _$id(GroceryStore e) {
    return e.id;
  }

  static String _$name(GroceryStore e) {
    return e.name;
  }

  static String _$marketName(GroceryStore e) {
    return e.marketName;
  }

  static double _$latitude(GroceryStore e) {
    return e.latitude;
  }

  static double _$longitude(GroceryStore e) {
    return e.longitude;
  }

  static double _$distance(GroceryStore e) {
    return e.distance;
  }

  static bool _$isSelected(GroceryStore e) {
    return e.isSelected;
  }
}

extension GroceryStoreCompareE on GroceryStore {
  Map<String, dynamic> compareToGroceryStore(GroceryStore other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (marketName != other.marketName) {
      diff['marketName'] = () => other.marketName;
    }

    if (latitude != other.latitude) {
      diff['latitude'] = () => other.latitude;
    }

    if (longitude != other.longitude) {
      diff['longitude'] = () => other.longitude;
    }

    if (distance != other.distance) {
      diff['distance'] = () => other.distance;
    }

    if (isSelected != other.isSelected) {
      diff['isSelected'] = () => other.isSelected;
    }
    return diff;
  }
}
