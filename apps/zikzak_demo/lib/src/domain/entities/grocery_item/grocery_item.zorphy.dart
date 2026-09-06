// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_item.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GroceryItem {
  GroceryItem({
    required String this.id,
    required String this.canonicalName,
    required String this.category,
    required List<String> this.detectionLabels,
    required Map<String, String> this.localizedName,
    List<GrocerySubVariety>? this.subVarieties,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) =>
      _$GroceryItemFromJson(json);

  final String id;

  final String canonicalName;

  final String category;

  final List<String> detectionLabels;

  final Map<String, String> localizedName;

  final List<GrocerySubVariety>? subVarieties;

  GroceryItem copyWith({
    String? id,
    String? canonicalName,
    String? category,
    List<String>? detectionLabels,
    Map<String, String>? localizedName,
    List<GrocerySubVariety>? subVarieties,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      canonicalName: canonicalName ?? this.canonicalName,
      category: category ?? this.category,
      detectionLabels: detectionLabels ?? this.detectionLabels,
      localizedName: localizedName ?? this.localizedName,
      subVarieties: subVarieties ?? this.subVarieties,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GroceryItem copyWithField<T>(Field<GroceryItem, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'canonicalName':
        return copyWith(canonicalName: value as String);
      case 'category':
        return copyWith(category: value as String);
      case 'detectionLabels':
        return copyWith(detectionLabels: value as List<String>);
      case 'localizedName':
        return copyWith(localizedName: value as Map<String, String>);
      case 'subVarieties':
        return copyWith(subVarieties: value as List<GrocerySubVariety>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GroceryItem has no settable field with this name',
        );
    }
  }

  GroceryItem copyWithGroceryItem({
    String? id,
    String? canonicalName,
    String? category,
    List<String>? detectionLabels,
    Map<String, String>? localizedName,
    List<GrocerySubVariety>? subVarieties,
  }) {
    return copyWith(
      id: id,
      canonicalName: canonicalName,
      category: category,
      detectionLabels: detectionLabels,
      localizedName: localizedName,
      subVarieties: subVarieties,
    );
  }

  GroceryItem patchWithGroceryItem([GroceryItemPatch? patchInput]) {
    final _patcher = patchInput ?? GroceryItemPatch();
    final _patchMap = _patcher.patchMap;
    return GroceryItem(
      id: _patchMap.containsKey(GroceryItem$.id)
          ? ((_patchMap[GroceryItem$.id] is Function)
                    ? _patchMap[GroceryItem$.id](this.id)
                    : (_patchMap[GroceryItem$.id] is Patch)
                    ? _patchMap[GroceryItem$.id].applyTo(this.id)
                    : _patchMap[GroceryItem$.id])
                as String
          : this.id,
      canonicalName: _patchMap.containsKey(GroceryItem$.canonicalName)
          ? ((_patchMap[GroceryItem$.canonicalName] is Function)
                    ? _patchMap[GroceryItem$.canonicalName](this.canonicalName)
                    : (_patchMap[GroceryItem$.canonicalName] is Patch)
                    ? _patchMap[GroceryItem$.canonicalName].applyTo(
                        this.canonicalName,
                      )
                    : _patchMap[GroceryItem$.canonicalName])
                as String
          : this.canonicalName,
      category: _patchMap.containsKey(GroceryItem$.category)
          ? ((_patchMap[GroceryItem$.category] is Function)
                    ? _patchMap[GroceryItem$.category](this.category)
                    : (_patchMap[GroceryItem$.category] is Patch)
                    ? _patchMap[GroceryItem$.category].applyTo(this.category)
                    : _patchMap[GroceryItem$.category])
                as String
          : this.category,
      detectionLabels: _patchMap.containsKey(GroceryItem$.detectionLabels)
          ? ((_patchMap[GroceryItem$.detectionLabels] is Function)
                    ? _patchMap[GroceryItem$.detectionLabels](
                        this.detectionLabels,
                      )
                    : (_patchMap[GroceryItem$.detectionLabels] is Patch)
                    ? _patchMap[GroceryItem$.detectionLabels].applyTo(
                        this.detectionLabels,
                      )
                    : _patchMap[GroceryItem$.detectionLabels])
                as List<String>
          : this.detectionLabels,
      localizedName: _patchMap.containsKey(GroceryItem$.localizedName)
          ? ((_patchMap[GroceryItem$.localizedName] is Function)
                    ? _patchMap[GroceryItem$.localizedName](this.localizedName)
                    : (_patchMap[GroceryItem$.localizedName] is Patch)
                    ? _patchMap[GroceryItem$.localizedName].applyTo(
                        this.localizedName,
                      )
                    : _patchMap[GroceryItem$.localizedName])
                as Map<String, String>
          : this.localizedName,
      subVarieties: _patchMap.containsKey(GroceryItem$.subVarieties)
          ? ((_patchMap[GroceryItem$.subVarieties] is Function)
                    ? _patchMap[GroceryItem$.subVarieties](this.subVarieties)
                    : (_patchMap[GroceryItem$.subVarieties] is Patch)
                    ? _patchMap[GroceryItem$.subVarieties].applyTo(
                        this.subVarieties,
                      )
                    : _patchMap[GroceryItem$.subVarieties])
                as List<GrocerySubVariety>?
          : this.subVarieties,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryItem &&
        id == other.id &&
        canonicalName == other.canonicalName &&
        category == other.category &&
        detectionLabels == other.detectionLabels &&
        localizedName == other.localizedName &&
        subVarieties == other.subVarieties;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.canonicalName,
      this.category,
      this.detectionLabels,
      this.localizedName,
      this.subVarieties,
    );
  }

  @override
  String toString() {
    return 'GroceryItem(' +
        'id: ${id}' +
        ', ' +
        'canonicalName: ${canonicalName}' +
        ', ' +
        'category: ${category}' +
        ', ' +
        'detectionLabels: ${detectionLabels}' +
        ', ' +
        'localizedName: ${localizedName}' +
        ', ' +
        'subVarieties: ${subVarieties})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GroceryItemToJson(this);
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

extension GroceryItemPropertyHelpers on GroceryItem {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasCanonicalName {
    return this.canonicalName.isNotEmpty;
  }

  bool get noCanonicalName {
    return this.canonicalName.isEmpty;
  }

  bool get hasCategory {
    return this.category.isNotEmpty;
  }

  bool get noCategory {
    return this.category.isEmpty;
  }

  bool get hasDetectionLabels {
    return this.detectionLabels.isNotEmpty;
  }

  bool get noDetectionLabels {
    return this.detectionLabels.isEmpty;
  }

  bool get hasLocalizedName {
    return this.localizedName.isNotEmpty;
  }

  bool get noLocalizedName {
    return this.localizedName.isEmpty;
  }

  List<GrocerySubVariety> get subVarietiesRequired {
    return this.subVarieties ??
        (throw StateError('subVarieties is required but was null'));
  }

  bool get hasSubVarieties {
    return this.subVarieties?.isNotEmpty ?? false;
  }

  bool get noSubVarieties {
    return this.subVarieties?.isEmpty ?? true;
  }
}

extension GroceryItemSerialization on GroceryItem {
  Map<String, dynamic> toJson() {
    return _$GroceryItemToJson(this);
  }
}

enum GroceryItem$ {
  id,
  canonicalName,
  category,
  detectionLabels,
  localizedName,
  subVarieties,
}

class GroceryItemPatch extends PatchBase<GroceryItem, GroceryItem$> {
  GroceryItem applyTo(GroceryItem entity) {
    return entity.patchWithGroceryItem(this);
  }

  GroceryItemPatch withId(String? value) {
    patchMap[GroceryItem$.id] = value;
    return this;
  }

  GroceryItemPatch withCanonicalName(String? value) {
    patchMap[GroceryItem$.canonicalName] = value;
    return this;
  }

  GroceryItemPatch withCategory(String? value) {
    patchMap[GroceryItem$.category] = value;
    return this;
  }

  GroceryItemPatch withDetectionLabels(List<String>? value) {
    patchMap[GroceryItem$.detectionLabels] = value;
    return this;
  }

  GroceryItemPatch withLocalizedName(Map<String, String>? value) {
    patchMap[GroceryItem$.localizedName] = value;
    return this;
  }

  GroceryItemPatch withSubVarieties(List<GrocerySubVariety>? value) {
    patchMap[GroceryItem$.subVarieties] = value;
    return this;
  }

  GroceryItemPatch updateSubVarietiesAt(
    int index,
    GrocerySubVarietyPatch Function(GrocerySubVarietyPatch) patch,
  ) {
    patchMap[GroceryItem$.subVarieties] = (List<dynamic> list) {
      var updatedList = List<GrocerySubVariety>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          GrocerySubVarietyPatch(),
        ).applyTo(updatedList[index] as GrocerySubVariety);
      }
      return updatedList;
    };
    return this;
  }
}

/// Field descriptors for [GroceryItem] query construction
abstract final class GroceryItemFields {
  static const id = Field<GroceryItem, String>('id', _$id);

  static const canonicalName = Field<GroceryItem, String>(
    'canonicalName',
    _$canonicalName,
  );

  static const category = Field<GroceryItem, String>('category', _$category);

  static const detectionLabels = Field<GroceryItem, List<String>>(
    'detectionLabels',
    _$detectionLabels,
  );

  static const localizedName = Field<GroceryItem, Map<String, String>>(
    'localizedName',
    _$localizedName,
  );

  static const subVarieties = Field<GroceryItem, List<GrocerySubVariety>?>(
    'subVarieties',
    _$subVarieties,
  );

  static String _$id(GroceryItem e) {
    return e.id;
  }

  static String _$canonicalName(GroceryItem e) {
    return e.canonicalName;
  }

  static String _$category(GroceryItem e) {
    return e.category;
  }

  static List<String> _$detectionLabels(GroceryItem e) {
    return e.detectionLabels;
  }

  static Map<String, String> _$localizedName(GroceryItem e) {
    return e.localizedName;
  }

  static List<GrocerySubVariety>? _$subVarieties(GroceryItem e) {
    return e.subVarieties;
  }
}

extension GroceryItemCompareE on GroceryItem {
  Map<String, dynamic> compareToGroceryItem(GroceryItem other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (canonicalName != other.canonicalName) {
      diff['canonicalName'] = () => other.canonicalName;
    }

    if (category != other.category) {
      diff['category'] = () => other.category;
    }

    if (detectionLabels != other.detectionLabels) {
      diff['detectionLabels'] = () => other.detectionLabels;
    }

    if (localizedName != other.localizedName) {
      diff['localizedName'] = () => other.localizedName;
    }

    if (subVarieties != other.subVarieties) {
      diff['subVarieties'] = () => other.subVarieties;
    }
    return diff;
  }
}
