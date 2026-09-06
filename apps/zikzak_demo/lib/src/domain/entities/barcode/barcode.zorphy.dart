// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'barcode.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Barcode {
  Barcode({required String this.value, required BarcodeFormat this.format});

  factory Barcode.fromJson(Map<String, dynamic> json) =>
      _$BarcodeFromJson(json);

  final String value;

  final BarcodeFormat format;

  Barcode copyWith({String? value, BarcodeFormat? format}) {
    return Barcode(value: value ?? this.value, format: format ?? this.format);
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Barcode copyWithField<T>(Field<Barcode, T> field, T value) {
    switch (field.name) {
      case 'value':
        return copyWith(value: value as String);
      case 'format':
        return copyWith(format: value as BarcodeFormat);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Barcode has no settable field with this name',
        );
    }
  }

  Barcode copyWithBarcode({String? value, BarcodeFormat? format}) {
    return copyWith(value: value, format: format);
  }

  Barcode patchWithBarcode([BarcodePatch? patchInput]) {
    final _patcher = patchInput ?? BarcodePatch();
    final _patchMap = _patcher.patchMap;
    return Barcode(
      value: _patchMap.containsKey(Barcode$.value)
          ? ((_patchMap[Barcode$.value] is Function)
                    ? _patchMap[Barcode$.value](this.value)
                    : (_patchMap[Barcode$.value] is Patch)
                    ? _patchMap[Barcode$.value].applyTo(this.value)
                    : _patchMap[Barcode$.value])
                as String
          : this.value,
      format: _patchMap.containsKey(Barcode$.format)
          ? ((_patchMap[Barcode$.format] is Function)
                    ? _patchMap[Barcode$.format](this.format)
                    : (_patchMap[Barcode$.format] is Patch)
                    ? _patchMap[Barcode$.format].applyTo(this.format)
                    : _patchMap[Barcode$.format])
                as BarcodeFormat
          : this.format,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Barcode && value == other.value && format == other.format;
  }

  @override
  int get hashCode {
    return Object.hash(this.value, this.format);
  }

  @override
  String toString() {
    return 'Barcode(' + 'value: ${value}' + ', ' + 'format: ${format})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$BarcodeToJson(this);
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

extension BarcodePropertyHelpers on Barcode {
  bool get hasValue {
    return this.value.isNotEmpty;
  }

  bool get noValue {
    return this.value.isEmpty;
  }

  bool get isFormatEan13 {
    return this.format == BarcodeFormat.ean13;
  }

  bool get isFormatEan8 {
    return this.format == BarcodeFormat.ean8;
  }

  bool get isFormatUpca {
    return this.format == BarcodeFormat.upca;
  }

  bool get isFormatUpce {
    return this.format == BarcodeFormat.upce;
  }
}

extension BarcodeSerialization on Barcode {
  Map<String, dynamic> toJson() {
    return _$BarcodeToJson(this);
  }
}

enum Barcode$ { value, format }

class BarcodePatch extends PatchBase<Barcode, Barcode$> {
  Barcode applyTo(Barcode entity) {
    return entity.patchWithBarcode(this);
  }

  BarcodePatch withValue(String? value) {
    patchMap[Barcode$.value] = value;
    return this;
  }

  BarcodePatch withFormat(BarcodeFormat? value) {
    patchMap[Barcode$.format] = value;
    return this;
  }
}

/// Field descriptors for [Barcode] query construction
abstract final class BarcodeFields {
  static const value = Field<Barcode, String>('value', _$value);

  static const format = Field<Barcode, BarcodeFormat>('format', _$format);

  static String _$value(Barcode e) {
    return e.value;
  }

  static BarcodeFormat _$format(Barcode e) {
    return e.format;
  }
}

extension BarcodeCompareE on Barcode {
  Map<String, dynamic> compareToBarcode(Barcode other) {
    final Map<String, dynamic> diff = {};

    if (value != other.value) {
      diff['value'] = () => other.value;
    }

    if (format != other.format) {
      diff['format'] = () => other.format;
    }
    return diff;
  }
}
