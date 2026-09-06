// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_sub_variety.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GrocerySubVariety {
  GrocerySubVariety({
    required String this.id,
    required String this.name,
    Map<String, String>? this.localizedName,
  });

  factory GrocerySubVariety.fromJson(Map<String, dynamic> json) =>
      _$GrocerySubVarietyFromJson(json);

  final String id;

  final String name;

  final Map<String, String>? localizedName;

  GrocerySubVariety copyWith({
    String? id,
    String? name,
    Map<String, String>? localizedName,
  }) {
    return GrocerySubVariety(
      id: id ?? this.id,
      name: name ?? this.name,
      localizedName: localizedName ?? this.localizedName,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GrocerySubVariety copyWithField<T>(
    Field<GrocerySubVariety, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'name':
        return copyWith(name: value as String);
      case 'localizedName':
        return copyWith(localizedName: value as Map<String, String>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GrocerySubVariety has no settable field with this name',
        );
    }
  }

  GrocerySubVariety copyWithGrocerySubVariety({
    String? id,
    String? name,
    Map<String, String>? localizedName,
  }) {
    return copyWith(id: id, name: name, localizedName: localizedName);
  }

  GrocerySubVariety patchWithGrocerySubVariety([
    GrocerySubVarietyPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? GrocerySubVarietyPatch();
    final _patchMap = _patcher.patchMap;
    return GrocerySubVariety(
      id: _patchMap.containsKey(GrocerySubVariety$.id)
          ? ((_patchMap[GrocerySubVariety$.id] is Function)
                    ? _patchMap[GrocerySubVariety$.id](this.id)
                    : (_patchMap[GrocerySubVariety$.id] is Patch)
                    ? _patchMap[GrocerySubVariety$.id].applyTo(this.id)
                    : _patchMap[GrocerySubVariety$.id])
                as String
          : this.id,
      name: _patchMap.containsKey(GrocerySubVariety$.name_)
          ? ((_patchMap[GrocerySubVariety$.name_] is Function)
                    ? _patchMap[GrocerySubVariety$.name_](this.name)
                    : (_patchMap[GrocerySubVariety$.name_] is Patch)
                    ? _patchMap[GrocerySubVariety$.name_].applyTo(this.name)
                    : _patchMap[GrocerySubVariety$.name_])
                as String
          : this.name,
      localizedName: _patchMap.containsKey(GrocerySubVariety$.localizedName)
          ? ((_patchMap[GrocerySubVariety$.localizedName] is Function)
                    ? _patchMap[GrocerySubVariety$.localizedName](
                        this.localizedName,
                      )
                    : (_patchMap[GrocerySubVariety$.localizedName] is Patch)
                    ? _patchMap[GrocerySubVariety$.localizedName].applyTo(
                        this.localizedName,
                      )
                    : _patchMap[GrocerySubVariety$.localizedName])
                as Map<String, String>?
          : this.localizedName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GrocerySubVariety &&
        id == other.id &&
        name == other.name &&
        localizedName == other.localizedName;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.name, this.localizedName);
  }

  @override
  String toString() {
    return 'GrocerySubVariety(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'localizedName: ${localizedName})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GrocerySubVarietyToJson(this);
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

extension GrocerySubVarietyPropertyHelpers on GrocerySubVariety {
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

  Map<String, String> get localizedNameRequired {
    return this.localizedName ??
        (throw StateError('localizedName is required but was null'));
  }

  bool get hasLocalizedName {
    return this.localizedName?.isNotEmpty ?? false;
  }

  bool get noLocalizedName {
    return this.localizedName?.isEmpty ?? true;
  }
}

extension GrocerySubVarietySerialization on GrocerySubVariety {
  Map<String, dynamic> toJson() {
    return _$GrocerySubVarietyToJson(this);
  }
}

enum GrocerySubVariety$ { id, name_, localizedName }

class GrocerySubVarietyPatch
    extends PatchBase<GrocerySubVariety, GrocerySubVariety$> {
  GrocerySubVariety applyTo(GrocerySubVariety entity) {
    return entity.patchWithGrocerySubVariety(this);
  }

  GrocerySubVarietyPatch withId(String? value) {
    patchMap[GrocerySubVariety$.id] = value;
    return this;
  }

  GrocerySubVarietyPatch withName(String? value) {
    patchMap[GrocerySubVariety$.name_] = value;
    return this;
  }

  GrocerySubVarietyPatch withLocalizedName(Map<String, String>? value) {
    patchMap[GrocerySubVariety$.localizedName] = value;
    return this;
  }
}

/// Field descriptors for [GrocerySubVariety] query construction
abstract final class GrocerySubVarietyFields {
  static const id = Field<GrocerySubVariety, String>('id', _$id);

  static const name = Field<GrocerySubVariety, String>('name', _$name);

  static const localizedName = Field<GrocerySubVariety, Map<String, String>?>(
    'localizedName',
    _$localizedName,
  );

  static String _$id(GrocerySubVariety e) {
    return e.id;
  }

  static String _$name(GrocerySubVariety e) {
    return e.name;
  }

  static Map<String, String>? _$localizedName(GrocerySubVariety e) {
    return e.localizedName;
  }
}

extension GrocerySubVarietyCompareE on GrocerySubVariety {
  Map<String, dynamic> compareToGrocerySubVariety(GrocerySubVariety other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (localizedName != other.localizedName) {
      diff['localizedName'] = () => other.localizedName;
    }
    return diff;
  }
}
