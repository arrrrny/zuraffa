// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'product.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.createdAt,
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Product copyWithProduct({
    String? id,
    String? name,
    String? description,
    double? price,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      name: name,
      description: description,
      price: price,
      createdAt: createdAt,
    );
  }

  Product patchWithProduct({ProductPatch? patchInput}) {
    final _patcher = patchInput ?? ProductPatch();
    final _patchMap = _patcher.toPatch();
    return Product(
      id: _patchMap.containsKey(Product$.id)
          ? (_patchMap[Product$.id] is Function)
                ? _patchMap[Product$.id](this.id)
                : _patchMap[Product$.id]
          : this.id,
      name: _patchMap.containsKey(Product$.name)
          ? (_patchMap[Product$.name] is Function)
                ? _patchMap[Product$.name](this.name)
                : _patchMap[Product$.name]
          : this.name,
      description: _patchMap.containsKey(Product$.description)
          ? (_patchMap[Product$.description] is Function)
                ? _patchMap[Product$.description](this.description)
                : _patchMap[Product$.description]
          : this.description,
      price: _patchMap.containsKey(Product$.price)
          ? (_patchMap[Product$.price] is Function)
                ? _patchMap[Product$.price](this.price)
                : _patchMap[Product$.price]
          : this.price,
      createdAt: _patchMap.containsKey(Product$.createdAt)
          ? (_patchMap[Product$.createdAt] is Function)
                ? _patchMap[Product$.createdAt](this.createdAt)
                : _patchMap[Product$.createdAt]
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        id == other.id &&
        name == other.name &&
        description == other.description &&
        price == other.price &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.name,
      this.description,
      this.price,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Product(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  /// Creates a [Product] instance from JSON
  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ProductToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension ProductPropertyHelpers on Product {}

extension ProductSerialization on Product {
  Map<String, dynamic> toJson() => _$ProductToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ProductToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

enum Product$ { id, name, description, price, createdAt }

class ProductPatch implements Patch<Product> {
  final Map<Product$, dynamic> _patch = {};

  static ProductPatch create([Map<String, dynamic>? diff]) {
    final patch = ProductPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Product$.values.firstWhere((e) => e.name == key);
          if (value is Function) {
            patch._patch[enumValue] = value();
          } else {
            patch._patch[enumValue] = value;
          }
        } catch (_) {}
      });
    }
    return patch;
  }

  static ProductPatch fromPatch(Map<Product$, dynamic> patch) {
    final _patch = ProductPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Product$, dynamic> toPatch() => Map.from(_patch);

  Product applyTo(Product entity) {
    return entity.patchWithProduct(patchInput: this);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _patch.forEach((key, value) {
      if (value != null) {
        if (value is Function) {
          final result = value();
          json[key.name] = _convertToJson(result);
        } else {
          json[key.name] = _convertToJson(value);
        }
      }
    });
    return json;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.toString().split('.').last;
    if (value is List) return value.map((e) => _convertToJson(e)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    if (value is num || value is bool || value is String) return value;
    try {
      if (value?.toJsonLean != null) return value.toJsonLean();
    } catch (_) {}
    if (value?.toJson != null) return value.toJson();
    return value.toString();
  }

  static ProductPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  ProductPatch withId(String? value) {
    _patch[Product$.id] = value;
    return this;
  }

  ProductPatch withName(String? value) {
    _patch[Product$.name] = value;
    return this;
  }

  ProductPatch withDescription(String? value) {
    _patch[Product$.description] = value;
    return this;
  }

  ProductPatch withPrice(double? value) {
    _patch[Product$.price] = value;
    return this;
  }

  ProductPatch withCreatedAt(DateTime? value) {
    _patch[Product$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [Product] query construction
abstract final class ProductFields {
  static String _$getid(Product e) => e.id;
  static const id = Field<Product, String>('id', _$getid);
  static String _$getname(Product e) => e.name;
  static const name = Field<Product, String>('name', _$getname);
  static String _$getdescription(Product e) => e.description;
  static const description = Field<Product, String>(
    'description',
    _$getdescription,
  );
  static double _$getprice(Product e) => e.price;
  static const price = Field<Product, double>('price', _$getprice);
  static DateTime _$getcreatedAt(Product e) => e.createdAt;
  static const createdAt = Field<Product, DateTime>(
    'createdAt',
    _$getcreatedAt,
  );
}

extension ProductCompareE on Product {
  Map<String, dynamic> compareToProduct(Product other) {
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
    if (price != other.price) {
      diff['price'] = () => other.price;
    }
    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
