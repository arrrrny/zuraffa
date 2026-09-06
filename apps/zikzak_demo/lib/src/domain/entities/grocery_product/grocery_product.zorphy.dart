// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_product.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GroceryProduct {
  GroceryProduct({
    required String this.id,
    required String this.title,
    String? this.brand,
    String? this.imageUrl,
    String? this.volumeOrWeight,
    required List<String> this.categories,
    required String this.mainCategory,
    String? this.menuCategory,
    required List<StorePrice> this.storePrices,
  });

  factory GroceryProduct.fromJson(Map<String, dynamic> json) =>
      _$GroceryProductFromJson(json);

  final String id;

  final String title;

  final String? brand;

  final String? imageUrl;

  final String? volumeOrWeight;

  final List<String> categories;

  final String mainCategory;

  final String? menuCategory;

  final List<StorePrice> storePrices;

  GroceryProduct copyWith({
    String? id,
    String? title,
    String? brand,
    String? imageUrl,
    String? volumeOrWeight,
    List<String>? categories,
    String? mainCategory,
    String? menuCategory,
    List<StorePrice>? storePrices,
  }) {
    return GroceryProduct(
      id: id ?? this.id,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      volumeOrWeight: volumeOrWeight ?? this.volumeOrWeight,
      categories: categories ?? this.categories,
      mainCategory: mainCategory ?? this.mainCategory,
      menuCategory: menuCategory ?? this.menuCategory,
      storePrices: storePrices ?? this.storePrices,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GroceryProduct copyWithField<T>(Field<GroceryProduct, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'brand':
        return copyWith(brand: value as String?);
      case 'imageUrl':
        return copyWith(imageUrl: value as String?);
      case 'volumeOrWeight':
        return copyWith(volumeOrWeight: value as String?);
      case 'categories':
        return copyWith(categories: value as List<String>);
      case 'mainCategory':
        return copyWith(mainCategory: value as String);
      case 'menuCategory':
        return copyWith(menuCategory: value as String?);
      case 'storePrices':
        return copyWith(storePrices: value as List<StorePrice>);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GroceryProduct has no settable field with this name',
        );
    }
  }

  GroceryProduct copyWithGroceryProduct({
    String? id,
    String? title,
    String? brand,
    String? imageUrl,
    String? volumeOrWeight,
    List<String>? categories,
    String? mainCategory,
    String? menuCategory,
    List<StorePrice>? storePrices,
  }) {
    return copyWith(
      id: id,
      title: title,
      brand: brand,
      imageUrl: imageUrl,
      volumeOrWeight: volumeOrWeight,
      categories: categories,
      mainCategory: mainCategory,
      menuCategory: menuCategory,
      storePrices: storePrices,
    );
  }

  GroceryProduct patchWithGroceryProduct([GroceryProductPatch? patchInput]) {
    final _patcher = patchInput ?? GroceryProductPatch();
    final _patchMap = _patcher.patchMap;
    return GroceryProduct(
      id: _patchMap.containsKey(GroceryProduct$.id)
          ? ((_patchMap[GroceryProduct$.id] is Function)
                    ? _patchMap[GroceryProduct$.id](this.id)
                    : (_patchMap[GroceryProduct$.id] is Patch)
                    ? _patchMap[GroceryProduct$.id].applyTo(this.id)
                    : _patchMap[GroceryProduct$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(GroceryProduct$.title)
          ? ((_patchMap[GroceryProduct$.title] is Function)
                    ? _patchMap[GroceryProduct$.title](this.title)
                    : (_patchMap[GroceryProduct$.title] is Patch)
                    ? _patchMap[GroceryProduct$.title].applyTo(this.title)
                    : _patchMap[GroceryProduct$.title])
                as String
          : this.title,
      brand: _patchMap.containsKey(GroceryProduct$.brand)
          ? ((_patchMap[GroceryProduct$.brand] is Function)
                    ? _patchMap[GroceryProduct$.brand](this.brand)
                    : (_patchMap[GroceryProduct$.brand] is Patch)
                    ? _patchMap[GroceryProduct$.brand].applyTo(this.brand)
                    : _patchMap[GroceryProduct$.brand])
                as String?
          : this.brand,
      imageUrl: _patchMap.containsKey(GroceryProduct$.imageUrl)
          ? ((_patchMap[GroceryProduct$.imageUrl] is Function)
                    ? _patchMap[GroceryProduct$.imageUrl](this.imageUrl)
                    : (_patchMap[GroceryProduct$.imageUrl] is Patch)
                    ? _patchMap[GroceryProduct$.imageUrl].applyTo(this.imageUrl)
                    : _patchMap[GroceryProduct$.imageUrl])
                as String?
          : this.imageUrl,
      volumeOrWeight: _patchMap.containsKey(GroceryProduct$.volumeOrWeight)
          ? ((_patchMap[GroceryProduct$.volumeOrWeight] is Function)
                    ? _patchMap[GroceryProduct$.volumeOrWeight](
                        this.volumeOrWeight,
                      )
                    : (_patchMap[GroceryProduct$.volumeOrWeight] is Patch)
                    ? _patchMap[GroceryProduct$.volumeOrWeight].applyTo(
                        this.volumeOrWeight,
                      )
                    : _patchMap[GroceryProduct$.volumeOrWeight])
                as String?
          : this.volumeOrWeight,
      categories: _patchMap.containsKey(GroceryProduct$.categories)
          ? ((_patchMap[GroceryProduct$.categories] is Function)
                    ? _patchMap[GroceryProduct$.categories](this.categories)
                    : (_patchMap[GroceryProduct$.categories] is Patch)
                    ? _patchMap[GroceryProduct$.categories].applyTo(
                        this.categories,
                      )
                    : _patchMap[GroceryProduct$.categories])
                as List<String>
          : this.categories,
      mainCategory: _patchMap.containsKey(GroceryProduct$.mainCategory)
          ? ((_patchMap[GroceryProduct$.mainCategory] is Function)
                    ? _patchMap[GroceryProduct$.mainCategory](this.mainCategory)
                    : (_patchMap[GroceryProduct$.mainCategory] is Patch)
                    ? _patchMap[GroceryProduct$.mainCategory].applyTo(
                        this.mainCategory,
                      )
                    : _patchMap[GroceryProduct$.mainCategory])
                as String
          : this.mainCategory,
      menuCategory: _patchMap.containsKey(GroceryProduct$.menuCategory)
          ? ((_patchMap[GroceryProduct$.menuCategory] is Function)
                    ? _patchMap[GroceryProduct$.menuCategory](this.menuCategory)
                    : (_patchMap[GroceryProduct$.menuCategory] is Patch)
                    ? _patchMap[GroceryProduct$.menuCategory].applyTo(
                        this.menuCategory,
                      )
                    : _patchMap[GroceryProduct$.menuCategory])
                as String?
          : this.menuCategory,
      storePrices: _patchMap.containsKey(GroceryProduct$.storePrices)
          ? ((_patchMap[GroceryProduct$.storePrices] is Function)
                    ? _patchMap[GroceryProduct$.storePrices](this.storePrices)
                    : (_patchMap[GroceryProduct$.storePrices] is Patch)
                    ? _patchMap[GroceryProduct$.storePrices].applyTo(
                        this.storePrices,
                      )
                    : _patchMap[GroceryProduct$.storePrices])
                as List<StorePrice>
          : this.storePrices,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryProduct &&
        id == other.id &&
        title == other.title &&
        brand == other.brand &&
        imageUrl == other.imageUrl &&
        volumeOrWeight == other.volumeOrWeight &&
        categories == other.categories &&
        mainCategory == other.mainCategory &&
        menuCategory == other.menuCategory &&
        storePrices == other.storePrices;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.brand,
      this.imageUrl,
      this.volumeOrWeight,
      this.categories,
      this.mainCategory,
      this.menuCategory,
      this.storePrices,
    );
  }

  @override
  String toString() {
    return 'GroceryProduct(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'brand: ${brand}' +
        ', ' +
        'imageUrl: ${imageUrl}' +
        ', ' +
        'volumeOrWeight: ${volumeOrWeight}' +
        ', ' +
        'categories: ${categories}' +
        ', ' +
        'mainCategory: ${mainCategory}' +
        ', ' +
        'menuCategory: ${menuCategory}' +
        ', ' +
        'storePrices: ${storePrices})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GroceryProductToJson(this);
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

extension GroceryProductPropertyHelpers on GroceryProduct {
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

  bool get hasBrand {
    return this.brand?.isNotEmpty == true;
  }

  bool get noBrand {
    return this.brand?.isEmpty ?? true;
  }

  String get brandRequired {
    return this.brand ?? (throw StateError('brand is required but was null'));
  }

  bool get hasImageUrl {
    return this.imageUrl?.isNotEmpty == true;
  }

  bool get noImageUrl {
    return this.imageUrl?.isEmpty ?? true;
  }

  String get imageUrlRequired {
    return this.imageUrl ??
        (throw StateError('imageUrl is required but was null'));
  }

  bool get hasVolumeOrWeight {
    return this.volumeOrWeight?.isNotEmpty == true;
  }

  bool get noVolumeOrWeight {
    return this.volumeOrWeight?.isEmpty ?? true;
  }

  String get volumeOrWeightRequired {
    return this.volumeOrWeight ??
        (throw StateError('volumeOrWeight is required but was null'));
  }

  bool get hasCategories {
    return this.categories.isNotEmpty;
  }

  bool get noCategories {
    return this.categories.isEmpty;
  }

  bool get hasMainCategory {
    return this.mainCategory.isNotEmpty;
  }

  bool get noMainCategory {
    return this.mainCategory.isEmpty;
  }

  bool get hasMenuCategory {
    return this.menuCategory?.isNotEmpty == true;
  }

  bool get noMenuCategory {
    return this.menuCategory?.isEmpty ?? true;
  }

  String get menuCategoryRequired {
    return this.menuCategory ??
        (throw StateError('menuCategory is required but was null'));
  }

  bool get hasStorePrices {
    return this.storePrices.isNotEmpty;
  }

  bool get noStorePrices {
    return this.storePrices.isEmpty;
  }
}

extension GroceryProductSerialization on GroceryProduct {
  Map<String, dynamic> toJson() {
    return _$GroceryProductToJson(this);
  }
}

enum GroceryProduct$ {
  id,
  title,
  brand,
  imageUrl,
  volumeOrWeight,
  categories,
  mainCategory,
  menuCategory,
  storePrices,
}

class GroceryProductPatch extends PatchBase<GroceryProduct, GroceryProduct$> {
  GroceryProduct applyTo(GroceryProduct entity) {
    return entity.patchWithGroceryProduct(this);
  }

  GroceryProductPatch withId(String? value) {
    patchMap[GroceryProduct$.id] = value;
    return this;
  }

  GroceryProductPatch withTitle(String? value) {
    patchMap[GroceryProduct$.title] = value;
    return this;
  }

  GroceryProductPatch withBrand(String? value) {
    patchMap[GroceryProduct$.brand] = value;
    return this;
  }

  GroceryProductPatch withImageUrl(String? value) {
    patchMap[GroceryProduct$.imageUrl] = value;
    return this;
  }

  GroceryProductPatch withVolumeOrWeight(String? value) {
    patchMap[GroceryProduct$.volumeOrWeight] = value;
    return this;
  }

  GroceryProductPatch withCategories(List<String>? value) {
    patchMap[GroceryProduct$.categories] = value;
    return this;
  }

  GroceryProductPatch withMainCategory(String? value) {
    patchMap[GroceryProduct$.mainCategory] = value;
    return this;
  }

  GroceryProductPatch withMenuCategory(String? value) {
    patchMap[GroceryProduct$.menuCategory] = value;
    return this;
  }

  GroceryProductPatch withStorePrices(List<StorePrice>? value) {
    patchMap[GroceryProduct$.storePrices] = value;
    return this;
  }

  GroceryProductPatch updateStorePricesAt(
    int index,
    StorePricePatch Function(StorePricePatch) patch,
  ) {
    patchMap[GroceryProduct$.storePrices] = (List<dynamic> list) {
      var updatedList = List<StorePrice>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          StorePricePatch(),
        ).applyTo(updatedList[index] as StorePrice);
      }
      return updatedList;
    };
    return this;
  }
}

/// Field descriptors for [GroceryProduct] query construction
abstract final class GroceryProductFields {
  static const id = Field<GroceryProduct, String>('id', _$id);

  static const title = Field<GroceryProduct, String>('title', _$title);

  static const brand = Field<GroceryProduct, String?>('brand', _$brand);

  static const imageUrl = Field<GroceryProduct, String?>(
    'imageUrl',
    _$imageUrl,
  );

  static const volumeOrWeight = Field<GroceryProduct, String?>(
    'volumeOrWeight',
    _$volumeOrWeight,
  );

  static const categories = Field<GroceryProduct, List<String>>(
    'categories',
    _$categories,
  );

  static const mainCategory = Field<GroceryProduct, String>(
    'mainCategory',
    _$mainCategory,
  );

  static const menuCategory = Field<GroceryProduct, String?>(
    'menuCategory',
    _$menuCategory,
  );

  static const storePrices = Field<GroceryProduct, List<StorePrice>>(
    'storePrices',
    _$storePrices,
  );

  static String _$id(GroceryProduct e) {
    return e.id;
  }

  static String _$title(GroceryProduct e) {
    return e.title;
  }

  static String? _$brand(GroceryProduct e) {
    return e.brand;
  }

  static String? _$imageUrl(GroceryProduct e) {
    return e.imageUrl;
  }

  static String? _$volumeOrWeight(GroceryProduct e) {
    return e.volumeOrWeight;
  }

  static List<String> _$categories(GroceryProduct e) {
    return e.categories;
  }

  static String _$mainCategory(GroceryProduct e) {
    return e.mainCategory;
  }

  static String? _$menuCategory(GroceryProduct e) {
    return e.menuCategory;
  }

  static List<StorePrice> _$storePrices(GroceryProduct e) {
    return e.storePrices;
  }
}

extension GroceryProductCompareE on GroceryProduct {
  Map<String, dynamic> compareToGroceryProduct(GroceryProduct other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (brand != other.brand) {
      diff['brand'] = () => other.brand;
    }

    if (imageUrl != other.imageUrl) {
      diff['imageUrl'] = () => other.imageUrl;
    }

    if (volumeOrWeight != other.volumeOrWeight) {
      diff['volumeOrWeight'] = () => other.volumeOrWeight;
    }

    if (categories != other.categories) {
      diff['categories'] = () => other.categories;
    }

    if (mainCategory != other.mainCategory) {
      diff['mainCategory'] = () => other.mainCategory;
    }

    if (menuCategory != other.menuCategory) {
      diff['menuCategory'] = () => other.menuCategory;
    }

    if (storePrices != other.storePrices) {
      diff['storePrices'] = () => other.storePrices;
    }
    return diff;
  }
}
