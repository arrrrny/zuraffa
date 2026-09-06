// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'barcode_listing.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class BarcodeListing {
  BarcodeListing({
    required String this.id,
    required String this.title,
    required String this.barcode,
  });

  factory BarcodeListing.fromJson(Map<String, dynamic> json) =>
      _$BarcodeListingFromJson(json);

  final String id;

  final String title;

  final String barcode;

  BarcodeListing copyWith({String? id, String? title, String? barcode}) {
    return BarcodeListing(
      id: id ?? this.id,
      title: title ?? this.title,
      barcode: barcode ?? this.barcode,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  BarcodeListing copyWithField<T>(Field<BarcodeListing, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'barcode':
        return copyWith(barcode: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'BarcodeListing has no settable field with this name',
        );
    }
  }

  BarcodeListing copyWithBarcodeListing({
    String? id,
    String? title,
    String? barcode,
  }) {
    return copyWith(id: id, title: title, barcode: barcode);
  }

  BarcodeListing patchWithBarcodeListing([BarcodeListingPatch? patchInput]) {
    final _patcher = patchInput ?? BarcodeListingPatch();
    final _patchMap = _patcher.patchMap;
    return BarcodeListing(
      id: _patchMap.containsKey(BarcodeListing$.id)
          ? ((_patchMap[BarcodeListing$.id] is Function)
                    ? _patchMap[BarcodeListing$.id](this.id)
                    : (_patchMap[BarcodeListing$.id] is Patch)
                    ? _patchMap[BarcodeListing$.id].applyTo(this.id)
                    : _patchMap[BarcodeListing$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(BarcodeListing$.title)
          ? ((_patchMap[BarcodeListing$.title] is Function)
                    ? _patchMap[BarcodeListing$.title](this.title)
                    : (_patchMap[BarcodeListing$.title] is Patch)
                    ? _patchMap[BarcodeListing$.title].applyTo(this.title)
                    : _patchMap[BarcodeListing$.title])
                as String
          : this.title,
      barcode: _patchMap.containsKey(BarcodeListing$.barcode)
          ? ((_patchMap[BarcodeListing$.barcode] is Function)
                    ? _patchMap[BarcodeListing$.barcode](this.barcode)
                    : (_patchMap[BarcodeListing$.barcode] is Patch)
                    ? _patchMap[BarcodeListing$.barcode].applyTo(this.barcode)
                    : _patchMap[BarcodeListing$.barcode])
                as String
          : this.barcode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeListing &&
        id == other.id &&
        title == other.title &&
        barcode == other.barcode;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.title, this.barcode);
  }

  @override
  String toString() {
    return 'BarcodeListing(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'barcode: ${barcode})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$BarcodeListingToJson(this);
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

extension BarcodeListingPropertyHelpers on BarcodeListing {
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

  bool get hasBarcode {
    return this.barcode.isNotEmpty;
  }

  bool get noBarcode {
    return this.barcode.isEmpty;
  }
}

extension BarcodeListingSerialization on BarcodeListing {
  Map<String, dynamic> toJson() {
    return _$BarcodeListingToJson(this);
  }
}

enum BarcodeListing$ { id, title, barcode }

class BarcodeListingPatch extends PatchBase<BarcodeListing, BarcodeListing$> {
  BarcodeListing applyTo(BarcodeListing entity) {
    return entity.patchWithBarcodeListing(this);
  }

  BarcodeListingPatch withId(String? value) {
    patchMap[BarcodeListing$.id] = value;
    return this;
  }

  BarcodeListingPatch withTitle(String? value) {
    patchMap[BarcodeListing$.title] = value;
    return this;
  }

  BarcodeListingPatch withBarcode(String? value) {
    patchMap[BarcodeListing$.barcode] = value;
    return this;
  }
}

/// Field descriptors for [BarcodeListing] query construction
abstract final class BarcodeListingFields {
  static const id = Field<BarcodeListing, String>('id', _$id);

  static const title = Field<BarcodeListing, String>('title', _$title);

  static const barcode = Field<BarcodeListing, String>('barcode', _$barcode);

  static String _$id(BarcodeListing e) {
    return e.id;
  }

  static String _$title(BarcodeListing e) {
    return e.title;
  }

  static String _$barcode(BarcodeListing e) {
    return e.barcode;
  }
}

extension BarcodeListingCompareE on BarcodeListing {
  Map<String, dynamic> compareToBarcodeListing(BarcodeListing other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (barcode != other.barcode) {
      diff['barcode'] = () => other.barcode;
    }
    return diff;
  }
}
