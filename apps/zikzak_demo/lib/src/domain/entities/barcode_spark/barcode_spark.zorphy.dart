// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'barcode_spark.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class BarcodeSpark {
  BarcodeSpark({
    String? id,
    required String this.barcode,
    String? this.sourceChannel,
  }) : this.id = id ?? const Uuid().v4();

  factory BarcodeSpark.fromJson(Map<String, dynamic> json) =>
      _$BarcodeSparkFromJson(json);

  final String id;

  final String barcode;

  final String? sourceChannel;

  BarcodeSpark copyWith({String? id, String? barcode, String? sourceChannel}) {
    return BarcodeSpark(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      sourceChannel: sourceChannel ?? this.sourceChannel,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  BarcodeSpark copyWithField<T>(Field<BarcodeSpark, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'barcode':
        return copyWith(barcode: value as String);
      case 'sourceChannel':
        return copyWith(sourceChannel: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'BarcodeSpark has no settable field with this name',
        );
    }
  }

  BarcodeSpark copyWithBarcodeSpark({
    String? id,
    String? barcode,
    String? sourceChannel,
  }) {
    return copyWith(id: id, barcode: barcode, sourceChannel: sourceChannel);
  }

  BarcodeSpark patchWithBarcodeSpark([BarcodeSparkPatch? patchInput]) {
    final _patcher = patchInput ?? BarcodeSparkPatch();
    final _patchMap = _patcher.patchMap;
    return BarcodeSpark(
      id: _patchMap.containsKey(BarcodeSpark$.id)
          ? ((_patchMap[BarcodeSpark$.id] is Function)
                    ? _patchMap[BarcodeSpark$.id](this.id)
                    : (_patchMap[BarcodeSpark$.id] is Patch)
                    ? _patchMap[BarcodeSpark$.id].applyTo(this.id)
                    : _patchMap[BarcodeSpark$.id])
                as String
          : this.id,
      barcode: _patchMap.containsKey(BarcodeSpark$.barcode)
          ? ((_patchMap[BarcodeSpark$.barcode] is Function)
                    ? _patchMap[BarcodeSpark$.barcode](this.barcode)
                    : (_patchMap[BarcodeSpark$.barcode] is Patch)
                    ? _patchMap[BarcodeSpark$.barcode].applyTo(this.barcode)
                    : _patchMap[BarcodeSpark$.barcode])
                as String
          : this.barcode,
      sourceChannel: _patchMap.containsKey(BarcodeSpark$.sourceChannel)
          ? ((_patchMap[BarcodeSpark$.sourceChannel] is Function)
                    ? _patchMap[BarcodeSpark$.sourceChannel](this.sourceChannel)
                    : (_patchMap[BarcodeSpark$.sourceChannel] is Patch)
                    ? _patchMap[BarcodeSpark$.sourceChannel].applyTo(
                        this.sourceChannel,
                      )
                    : _patchMap[BarcodeSpark$.sourceChannel])
                as String?
          : this.sourceChannel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeSpark &&
        id == other.id &&
        barcode == other.barcode &&
        sourceChannel == other.sourceChannel;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.barcode, this.sourceChannel);
  }

  @override
  String toString() {
    return 'BarcodeSpark(' +
        'id: ${id}' +
        ', ' +
        'barcode: ${barcode}' +
        ', ' +
        'sourceChannel: ${sourceChannel})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeSpark &&
        barcode == other.barcode &&
        sourceChannel == other.sourceChannel;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$BarcodeSparkToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$BarcodeSparkToJson(this);
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

extension BarcodeSparkPropertyHelpers on BarcodeSpark {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasBarcode {
    return this.barcode.isNotEmpty;
  }

  bool get noBarcode {
    return this.barcode.isEmpty;
  }

  bool get hasSourceChannel {
    return this.sourceChannel?.isNotEmpty == true;
  }

  bool get noSourceChannel {
    return this.sourceChannel?.isEmpty ?? true;
  }

  String get sourceChannelRequired {
    return this.sourceChannel ??
        (throw StateError('sourceChannel is required but was null'));
  }
}

extension BarcodeSparkSerialization on BarcodeSpark {
  Map<String, dynamic> toJson() {
    return _$BarcodeSparkToJson(this);
  }
}

enum BarcodeSpark$ { id, barcode, sourceChannel }

class BarcodeSparkPatch extends PatchBase<BarcodeSpark, BarcodeSpark$> {
  BarcodeSpark applyTo(BarcodeSpark entity) {
    return entity.patchWithBarcodeSpark(this);
  }

  BarcodeSparkPatch withId(String? value) {
    patchMap[BarcodeSpark$.id] = value;
    return this;
  }

  BarcodeSparkPatch withBarcode(String? value) {
    patchMap[BarcodeSpark$.barcode] = value;
    return this;
  }

  BarcodeSparkPatch withSourceChannel(String? value) {
    patchMap[BarcodeSpark$.sourceChannel] = value;
    return this;
  }
}

/// Field descriptors for [BarcodeSpark] query construction
abstract final class BarcodeSparkFields {
  static const id = Field<BarcodeSpark, String>('id', _$id);

  static const barcode = Field<BarcodeSpark, String>('barcode', _$barcode);

  static const sourceChannel = Field<BarcodeSpark, String?>(
    'sourceChannel',
    _$sourceChannel,
  );

  static String _$id(BarcodeSpark e) {
    return e.id;
  }

  static String _$barcode(BarcodeSpark e) {
    return e.barcode;
  }

  static String? _$sourceChannel(BarcodeSpark e) {
    return e.sourceChannel;
  }
}

extension BarcodeSparkCompareE on BarcodeSpark {
  Map<String, dynamic> compareToBarcodeSpark(BarcodeSpark other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (barcode != other.barcode) {
      diff['barcode'] = () => other.barcode;
    }

    if (sourceChannel != other.sourceChannel) {
      diff['sourceChannel'] = () => other.sourceChannel;
    }
    return diff;
  }
}
