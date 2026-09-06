// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'category.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Category {
  Category({
    required String this.id,
    required String this.name,
    String? this.description,
    required ProductCategory this.type,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  final String id;

  final String name;

  final String? description;

  final ProductCategory type;

  Category copyWith({
    String? id,
    String? name,
    String? description,
    ProductCategory? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Category copyWithField<T>(Field<Category, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'name':
        return copyWith(name: value as String);
      case 'description':
        return copyWith(description: value as String?);
      case 'type':
        return copyWith(type: value as ProductCategory);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Category has no settable field with this name',
        );
    }
  }

  Category copyWithCategory({
    String? id,
    String? name,
    String? description,
    ProductCategory? type,
  }) {
    return copyWith(id: id, name: name, description: description, type: type);
  }

  Category patchWithCategory([CategoryPatch? patchInput]) {
    final _patcher = patchInput ?? CategoryPatch();
    final _patchMap = _patcher.patchMap;
    return Category(
      id: _patchMap.containsKey(Category$.id)
          ? ((_patchMap[Category$.id] is Function)
                    ? _patchMap[Category$.id](this.id)
                    : (_patchMap[Category$.id] is Patch)
                    ? _patchMap[Category$.id].applyTo(this.id)
                    : _patchMap[Category$.id])
                as String
          : this.id,
      name: _patchMap.containsKey(Category$.name_)
          ? ((_patchMap[Category$.name_] is Function)
                    ? _patchMap[Category$.name_](this.name)
                    : (_patchMap[Category$.name_] is Patch)
                    ? _patchMap[Category$.name_].applyTo(this.name)
                    : _patchMap[Category$.name_])
                as String
          : this.name,
      description: _patchMap.containsKey(Category$.description)
          ? ((_patchMap[Category$.description] is Function)
                    ? _patchMap[Category$.description](this.description)
                    : (_patchMap[Category$.description] is Patch)
                    ? _patchMap[Category$.description].applyTo(this.description)
                    : _patchMap[Category$.description])
                as String?
          : this.description,
      type: _patchMap.containsKey(Category$.type)
          ? ((_patchMap[Category$.type] is Function)
                    ? _patchMap[Category$.type](this.type)
                    : (_patchMap[Category$.type] is Patch)
                    ? _patchMap[Category$.type].applyTo(this.type)
                    : _patchMap[Category$.type])
                as ProductCategory
          : this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        id == other.id &&
        name == other.name &&
        description == other.description &&
        type == other.type;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.name, this.description, this.type);
  }

  @override
  String toString() {
    return 'Category(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'type: ${type})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CategoryToJson(this);
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

extension CategoryPropertyHelpers on Category {
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

  bool get hasDescription {
    return this.description?.isNotEmpty == true;
  }

  bool get noDescription {
    return this.description?.isEmpty ?? true;
  }

  String get descriptionRequired {
    return this.description ??
        (throw StateError('description is required but was null'));
  }

  bool get isTypeMarketplace {
    return this.type == ProductCategory.marketplace;
  }

  bool get isTypeBeauty {
    return this.type == ProductCategory.beauty;
  }

  bool get isTypeMenApparel {
    return this.type == ProductCategory.menApparel;
  }

  bool get isTypeWomenApparel {
    return this.type == ProductCategory.womenApparel;
  }

  bool get isTypeHomeImprovement {
    return this.type == ProductCategory.homeImprovement;
  }

  bool get isTypeElectronics {
    return this.type == ProductCategory.electronics;
  }

  bool get isTypeBaby {
    return this.type == ProductCategory.baby;
  }

  bool get isTypeKids {
    return this.type == ProductCategory.kids;
  }

  bool get isTypeGrocery {
    return this.type == ProductCategory.grocery;
  }

  bool get isTypeOfficeSupplies {
    return this.type == ProductCategory.officeSupplies;
  }

  bool get isTypeOther {
    return this.type == ProductCategory.other;
  }
}

extension CategorySerialization on Category {
  Map<String, dynamic> toJson() {
    return _$CategoryToJson(this);
  }
}

enum Category$ { id, name_, description, type }

class CategoryPatch extends PatchBase<Category, Category$> {
  Category applyTo(Category entity) {
    return entity.patchWithCategory(this);
  }

  CategoryPatch withId(String? value) {
    patchMap[Category$.id] = value;
    return this;
  }

  CategoryPatch withName(String? value) {
    patchMap[Category$.name_] = value;
    return this;
  }

  CategoryPatch withDescription(String? value) {
    patchMap[Category$.description] = value;
    return this;
  }

  CategoryPatch withType(ProductCategory? value) {
    patchMap[Category$.type] = value;
    return this;
  }
}

/// Field descriptors for [Category] query construction
abstract final class CategoryFields {
  static const id = Field<Category, String>('id', _$id);

  static const name = Field<Category, String>('name', _$name);

  static const description = Field<Category, String?>(
    'description',
    _$description,
  );

  static const type = Field<Category, ProductCategory>('type', _$type);

  static String _$id(Category e) {
    return e.id;
  }

  static String _$name(Category e) {
    return e.name;
  }

  static String? _$description(Category e) {
    return e.description;
  }

  static ProductCategory _$type(Category e) {
    return e.type;
  }
}

extension CategoryCompareE on Category {
  Map<String, dynamic> compareToCategory(Category other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (description != other.description) {
      diff['description'] = () => other.description;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }
    return diff;
  }
}
