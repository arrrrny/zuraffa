// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'grocery_price_comparison.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class GroceryPriceComparison {
  GroceryPriceComparison({
    required String this.itemName,
    String? this.itemId,
    String? this.selectedSubVariety,
    required List<GroceryPriceResult> this.prices,
    required String this.detectionSource,
    required double this.detectionConfidence,
  });

  factory GroceryPriceComparison.fromJson(Map<String, dynamic> json) =>
      _$GroceryPriceComparisonFromJson(json);

  final String itemName;

  final String? itemId;

  final String? selectedSubVariety;

  final List<GroceryPriceResult> prices;

  final String detectionSource;

  final double detectionConfidence;

  GroceryPriceComparison copyWith({
    String? itemName,
    String? itemId,
    String? selectedSubVariety,
    List<GroceryPriceResult>? prices,
    String? detectionSource,
    double? detectionConfidence,
  }) {
    return GroceryPriceComparison(
      itemName: itemName ?? this.itemName,
      itemId: itemId ?? this.itemId,
      selectedSubVariety: selectedSubVariety ?? this.selectedSubVariety,
      prices: prices ?? this.prices,
      detectionSource: detectionSource ?? this.detectionSource,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  GroceryPriceComparison copyWithField<T>(
    Field<GroceryPriceComparison, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'itemName':
        return copyWith(itemName: value as String);
      case 'itemId':
        return copyWith(itemId: value as String?);
      case 'selectedSubVariety':
        return copyWith(selectedSubVariety: value as String?);
      case 'prices':
        return copyWith(prices: value as List<GroceryPriceResult>);
      case 'detectionSource':
        return copyWith(detectionSource: value as String);
      case 'detectionConfidence':
        return copyWith(detectionConfidence: value as double);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'GroceryPriceComparison has no settable field with this name',
        );
    }
  }

  GroceryPriceComparison copyWithGroceryPriceComparison({
    String? itemName,
    String? itemId,
    String? selectedSubVariety,
    List<GroceryPriceResult>? prices,
    String? detectionSource,
    double? detectionConfidence,
  }) {
    return copyWith(
      itemName: itemName,
      itemId: itemId,
      selectedSubVariety: selectedSubVariety,
      prices: prices,
      detectionSource: detectionSource,
      detectionConfidence: detectionConfidence,
    );
  }

  GroceryPriceComparison patchWithGroceryPriceComparison([
    GroceryPriceComparisonPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? GroceryPriceComparisonPatch();
    final _patchMap = _patcher.patchMap;
    return GroceryPriceComparison(
      itemName: _patchMap.containsKey(GroceryPriceComparison$.itemName)
          ? ((_patchMap[GroceryPriceComparison$.itemName] is Function)
                    ? _patchMap[GroceryPriceComparison$.itemName](this.itemName)
                    : (_patchMap[GroceryPriceComparison$.itemName] is Patch)
                    ? _patchMap[GroceryPriceComparison$.itemName].applyTo(
                        this.itemName,
                      )
                    : _patchMap[GroceryPriceComparison$.itemName])
                as String
          : this.itemName,
      itemId: _patchMap.containsKey(GroceryPriceComparison$.itemId)
          ? ((_patchMap[GroceryPriceComparison$.itemId] is Function)
                    ? _patchMap[GroceryPriceComparison$.itemId](this.itemId)
                    : (_patchMap[GroceryPriceComparison$.itemId] is Patch)
                    ? _patchMap[GroceryPriceComparison$.itemId].applyTo(
                        this.itemId,
                      )
                    : _patchMap[GroceryPriceComparison$.itemId])
                as String?
          : this.itemId,
      selectedSubVariety:
          _patchMap.containsKey(GroceryPriceComparison$.selectedSubVariety)
          ? ((_patchMap[GroceryPriceComparison$.selectedSubVariety] is Function)
                    ? _patchMap[GroceryPriceComparison$.selectedSubVariety](
                        this.selectedSubVariety,
                      )
                    : (_patchMap[GroceryPriceComparison$.selectedSubVariety]
                          is Patch)
                    ? _patchMap[GroceryPriceComparison$.selectedSubVariety]
                          .applyTo(this.selectedSubVariety)
                    : _patchMap[GroceryPriceComparison$.selectedSubVariety])
                as String?
          : this.selectedSubVariety,
      prices: _patchMap.containsKey(GroceryPriceComparison$.prices)
          ? ((_patchMap[GroceryPriceComparison$.prices] is Function)
                    ? _patchMap[GroceryPriceComparison$.prices](this.prices)
                    : (_patchMap[GroceryPriceComparison$.prices] is Patch)
                    ? _patchMap[GroceryPriceComparison$.prices].applyTo(
                        this.prices,
                      )
                    : _patchMap[GroceryPriceComparison$.prices])
                as List<GroceryPriceResult>
          : this.prices,
      detectionSource:
          _patchMap.containsKey(GroceryPriceComparison$.detectionSource)
          ? ((_patchMap[GroceryPriceComparison$.detectionSource] is Function)
                    ? _patchMap[GroceryPriceComparison$.detectionSource](
                        this.detectionSource,
                      )
                    : (_patchMap[GroceryPriceComparison$.detectionSource]
                          is Patch)
                    ? _patchMap[GroceryPriceComparison$.detectionSource]
                          .applyTo(this.detectionSource)
                    : _patchMap[GroceryPriceComparison$.detectionSource])
                as String
          : this.detectionSource,
      detectionConfidence:
          _patchMap.containsKey(GroceryPriceComparison$.detectionConfidence)
          ? ((_patchMap[GroceryPriceComparison$.detectionConfidence]
                        is Function)
                    ? _patchMap[GroceryPriceComparison$.detectionConfidence](
                        this.detectionConfidence,
                      )
                    : (_patchMap[GroceryPriceComparison$.detectionConfidence]
                          is Patch)
                    ? _patchMap[GroceryPriceComparison$.detectionConfidence]
                          .applyTo(this.detectionConfidence)
                    : _patchMap[GroceryPriceComparison$.detectionConfidence])
                as double
          : this.detectionConfidence,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryPriceComparison &&
        itemName == other.itemName &&
        itemId == other.itemId &&
        selectedSubVariety == other.selectedSubVariety &&
        prices == other.prices &&
        detectionSource == other.detectionSource &&
        detectionConfidence == other.detectionConfidence;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.itemName,
      this.itemId,
      this.selectedSubVariety,
      this.prices,
      this.detectionSource,
      this.detectionConfidence,
    );
  }

  @override
  String toString() {
    return 'GroceryPriceComparison(' +
        'itemName: ${itemName}' +
        ', ' +
        'itemId: ${itemId}' +
        ', ' +
        'selectedSubVariety: ${selectedSubVariety}' +
        ', ' +
        'prices: ${prices}' +
        ', ' +
        'detectionSource: ${detectionSource}' +
        ', ' +
        'detectionConfidence: ${detectionConfidence})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$GroceryPriceComparisonToJson(this);
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

extension GroceryPriceComparisonPropertyHelpers on GroceryPriceComparison {
  bool get hasItemName {
    return this.itemName.isNotEmpty;
  }

  bool get noItemName {
    return this.itemName.isEmpty;
  }

  bool get hasItemId {
    return this.itemId?.isNotEmpty == true;
  }

  bool get noItemId {
    return this.itemId?.isEmpty ?? true;
  }

  String get itemIdRequired {
    return this.itemId ?? (throw StateError('itemId is required but was null'));
  }

  bool get hasSelectedSubVariety {
    return this.selectedSubVariety?.isNotEmpty == true;
  }

  bool get noSelectedSubVariety {
    return this.selectedSubVariety?.isEmpty ?? true;
  }

  String get selectedSubVarietyRequired {
    return this.selectedSubVariety ??
        (throw StateError('selectedSubVariety is required but was null'));
  }

  bool get hasPrices {
    return this.prices.isNotEmpty;
  }

  bool get noPrices {
    return this.prices.isEmpty;
  }

  bool get hasDetectionSource {
    return this.detectionSource.isNotEmpty;
  }

  bool get noDetectionSource {
    return this.detectionSource.isEmpty;
  }
}

extension GroceryPriceComparisonSerialization on GroceryPriceComparison {
  Map<String, dynamic> toJson() {
    return _$GroceryPriceComparisonToJson(this);
  }
}

enum GroceryPriceComparison$ {
  itemName,
  itemId,
  selectedSubVariety,
  prices,
  detectionSource,
  detectionConfidence,
}

class GroceryPriceComparisonPatch
    extends PatchBase<GroceryPriceComparison, GroceryPriceComparison$> {
  GroceryPriceComparison applyTo(GroceryPriceComparison entity) {
    return entity.patchWithGroceryPriceComparison(this);
  }

  GroceryPriceComparisonPatch withItemName(String? value) {
    patchMap[GroceryPriceComparison$.itemName] = value;
    return this;
  }

  GroceryPriceComparisonPatch withItemId(String? value) {
    patchMap[GroceryPriceComparison$.itemId] = value;
    return this;
  }

  GroceryPriceComparisonPatch withSelectedSubVariety(String? value) {
    patchMap[GroceryPriceComparison$.selectedSubVariety] = value;
    return this;
  }

  GroceryPriceComparisonPatch withPrices(List<GroceryPriceResult>? value) {
    patchMap[GroceryPriceComparison$.prices] = value;
    return this;
  }

  GroceryPriceComparisonPatch updatePricesAt(
    int index,
    GroceryPriceResultPatch Function(GroceryPriceResultPatch) patch,
  ) {
    patchMap[GroceryPriceComparison$.prices] = (List<dynamic> list) {
      var updatedList = List<GroceryPriceResult>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          GroceryPriceResultPatch(),
        ).applyTo(updatedList[index] as GroceryPriceResult);
      }
      return updatedList;
    };
    return this;
  }

  GroceryPriceComparisonPatch withDetectionSource(String? value) {
    patchMap[GroceryPriceComparison$.detectionSource] = value;
    return this;
  }

  GroceryPriceComparisonPatch withDetectionConfidence(double? value) {
    patchMap[GroceryPriceComparison$.detectionConfidence] = value;
    return this;
  }
}

/// Field descriptors for [GroceryPriceComparison] query construction
abstract final class GroceryPriceComparisonFields {
  static const itemName = Field<GroceryPriceComparison, String>(
    'itemName',
    _$itemName,
  );

  static const itemId = Field<GroceryPriceComparison, String?>(
    'itemId',
    _$itemId,
  );

  static const selectedSubVariety = Field<GroceryPriceComparison, String?>(
    'selectedSubVariety',
    _$selectedSubVariety,
  );

  static const prices = Field<GroceryPriceComparison, List<GroceryPriceResult>>(
    'prices',
    _$prices,
  );

  static const detectionSource = Field<GroceryPriceComparison, String>(
    'detectionSource',
    _$detectionSource,
  );

  static const detectionConfidence = Field<GroceryPriceComparison, double>(
    'detectionConfidence',
    _$detectionConfidence,
  );

  static String _$itemName(GroceryPriceComparison e) {
    return e.itemName;
  }

  static String? _$itemId(GroceryPriceComparison e) {
    return e.itemId;
  }

  static String? _$selectedSubVariety(GroceryPriceComparison e) {
    return e.selectedSubVariety;
  }

  static List<GroceryPriceResult> _$prices(GroceryPriceComparison e) {
    return e.prices;
  }

  static String _$detectionSource(GroceryPriceComparison e) {
    return e.detectionSource;
  }

  static double _$detectionConfidence(GroceryPriceComparison e) {
    return e.detectionConfidence;
  }
}

extension GroceryPriceComparisonCompareE on GroceryPriceComparison {
  Map<String, dynamic> compareToGroceryPriceComparison(
    GroceryPriceComparison other,
  ) {
    final Map<String, dynamic> diff = {};

    if (itemName != other.itemName) {
      diff['itemName'] = () => other.itemName;
    }

    if (itemId != other.itemId) {
      diff['itemId'] = () => other.itemId;
    }

    if (selectedSubVariety != other.selectedSubVariety) {
      diff['selectedSubVariety'] = () => other.selectedSubVariety;
    }

    if (prices != other.prices) {
      diff['prices'] = () => other.prices;
    }

    if (detectionSource != other.detectionSource) {
      diff['detectionSource'] = () => other.detectionSource;
    }

    if (detectionConfidence != other.detectionConfidence) {
      diff['detectionConfidence'] = () => other.detectionConfidence;
    }
    return diff;
  }
}
