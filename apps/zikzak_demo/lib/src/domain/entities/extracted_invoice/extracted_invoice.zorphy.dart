// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'extracted_invoice.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ExtractedInvoice {
  ExtractedInvoice({
    String? this.id,
    String? this.storeName,
    double? this.total,
    String? this.currencyCode,
    List<String>? this.items,
    DateTime? this.purchaseDate,
  });

  factory ExtractedInvoice.fromJson(Map<String, dynamic> json) =>
      _$ExtractedInvoiceFromJson(json);

  final String? id;

  final String? storeName;

  final double? total;

  final String? currencyCode;

  final List<String>? items;

  final DateTime? purchaseDate;

  ExtractedInvoice copyWith({
    String? id,
    String? storeName,
    double? total,
    String? currencyCode,
    List<String>? items,
    DateTime? purchaseDate,
  }) {
    return ExtractedInvoice(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      total: total ?? this.total,
      currencyCode: currencyCode ?? this.currencyCode,
      items: items ?? this.items,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ExtractedInvoice copyWithField<T>(Field<ExtractedInvoice, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'storeName':
        return copyWith(storeName: value as String?);
      case 'total':
        return copyWith(total: value as double?);
      case 'currencyCode':
        return copyWith(currencyCode: value as String?);
      case 'items':
        return copyWith(items: value as List<String>?);
      case 'purchaseDate':
        return copyWith(purchaseDate: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ExtractedInvoice has no settable field with this name',
        );
    }
  }

  ExtractedInvoice copyWithExtractedInvoice({
    String? id,
    String? storeName,
    double? total,
    String? currencyCode,
    List<String>? items,
    DateTime? purchaseDate,
  }) {
    return copyWith(
      id: id,
      storeName: storeName,
      total: total,
      currencyCode: currencyCode,
      items: items,
      purchaseDate: purchaseDate,
    );
  }

  ExtractedInvoice patchWithExtractedInvoice([
    ExtractedInvoicePatch? patchInput,
  ]) {
    final _patcher = patchInput ?? ExtractedInvoicePatch();
    final _patchMap = _patcher.patchMap;
    return ExtractedInvoice(
      id: _patchMap.containsKey(ExtractedInvoice$.id)
          ? ((_patchMap[ExtractedInvoice$.id] is Function)
                    ? _patchMap[ExtractedInvoice$.id](this.id)
                    : (_patchMap[ExtractedInvoice$.id] is Patch)
                    ? _patchMap[ExtractedInvoice$.id].applyTo(this.id)
                    : _patchMap[ExtractedInvoice$.id])
                as String?
          : this.id,
      storeName: _patchMap.containsKey(ExtractedInvoice$.storeName)
          ? ((_patchMap[ExtractedInvoice$.storeName] is Function)
                    ? _patchMap[ExtractedInvoice$.storeName](this.storeName)
                    : (_patchMap[ExtractedInvoice$.storeName] is Patch)
                    ? _patchMap[ExtractedInvoice$.storeName].applyTo(
                        this.storeName,
                      )
                    : _patchMap[ExtractedInvoice$.storeName])
                as String?
          : this.storeName,
      total: _patchMap.containsKey(ExtractedInvoice$.total)
          ? ((_patchMap[ExtractedInvoice$.total] is Function)
                    ? _patchMap[ExtractedInvoice$.total](this.total)
                    : (_patchMap[ExtractedInvoice$.total] is Patch)
                    ? _patchMap[ExtractedInvoice$.total].applyTo(this.total)
                    : _patchMap[ExtractedInvoice$.total])
                as double?
          : this.total,
      currencyCode: _patchMap.containsKey(ExtractedInvoice$.currencyCode)
          ? ((_patchMap[ExtractedInvoice$.currencyCode] is Function)
                    ? _patchMap[ExtractedInvoice$.currencyCode](
                        this.currencyCode,
                      )
                    : (_patchMap[ExtractedInvoice$.currencyCode] is Patch)
                    ? _patchMap[ExtractedInvoice$.currencyCode].applyTo(
                        this.currencyCode,
                      )
                    : _patchMap[ExtractedInvoice$.currencyCode])
                as String?
          : this.currencyCode,
      items: _patchMap.containsKey(ExtractedInvoice$.items)
          ? ((_patchMap[ExtractedInvoice$.items] is Function)
                    ? _patchMap[ExtractedInvoice$.items](this.items)
                    : (_patchMap[ExtractedInvoice$.items] is Patch)
                    ? _patchMap[ExtractedInvoice$.items].applyTo(this.items)
                    : _patchMap[ExtractedInvoice$.items])
                as List<String>?
          : this.items,
      purchaseDate: _patchMap.containsKey(ExtractedInvoice$.purchaseDate)
          ? ((_patchMap[ExtractedInvoice$.purchaseDate] is Function)
                    ? _patchMap[ExtractedInvoice$.purchaseDate](
                        this.purchaseDate,
                      )
                    : (_patchMap[ExtractedInvoice$.purchaseDate] is Patch)
                    ? _patchMap[ExtractedInvoice$.purchaseDate].applyTo(
                        this.purchaseDate,
                      )
                    : _patchMap[ExtractedInvoice$.purchaseDate])
                as DateTime?
          : this.purchaseDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtractedInvoice &&
        id == other.id &&
        storeName == other.storeName &&
        total == other.total &&
        currencyCode == other.currencyCode &&
        items == other.items &&
        purchaseDate == other.purchaseDate;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.storeName,
      this.total,
      this.currencyCode,
      this.items,
      this.purchaseDate,
    );
  }

  @override
  String toString() {
    return 'ExtractedInvoice(' +
        'id: ${id}' +
        ', ' +
        'storeName: ${storeName}' +
        ', ' +
        'total: ${total}' +
        ', ' +
        'currencyCode: ${currencyCode}' +
        ', ' +
        'items: ${items}' +
        ', ' +
        'purchaseDate: ${purchaseDate})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ExtractedInvoiceToJson(this);
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

extension ExtractedInvoicePropertyHelpers on ExtractedInvoice {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasStoreName {
    return this.storeName?.isNotEmpty == true;
  }

  bool get noStoreName {
    return this.storeName?.isEmpty ?? true;
  }

  String get storeNameRequired {
    return this.storeName ??
        (throw StateError('storeName is required but was null'));
  }

  bool get hasTotal {
    return this.total != null;
  }

  bool get noTotal {
    return this.total == null;
  }

  double get totalRequired {
    return this.total ?? (throw StateError('total is required but was null'));
  }

  bool get hasCurrencyCode {
    return this.currencyCode?.isNotEmpty == true;
  }

  bool get noCurrencyCode {
    return this.currencyCode?.isEmpty ?? true;
  }

  String get currencyCodeRequired {
    return this.currencyCode ??
        (throw StateError('currencyCode is required but was null'));
  }

  List<String> get itemsRequired {
    return this.items ?? (throw StateError('items is required but was null'));
  }

  bool get hasItems {
    return this.items?.isNotEmpty ?? false;
  }

  bool get noItems {
    return this.items?.isEmpty ?? true;
  }

  bool get hasPurchaseDate {
    return this.purchaseDate != null;
  }

  bool get noPurchaseDate {
    return this.purchaseDate == null;
  }

  DateTime get purchaseDateRequired {
    return this.purchaseDate ??
        (throw StateError('purchaseDate is required but was null'));
  }
}

extension ExtractedInvoiceSerialization on ExtractedInvoice {
  Map<String, dynamic> toJson() {
    return _$ExtractedInvoiceToJson(this);
  }
}

enum ExtractedInvoice$ {
  id,
  storeName,
  total,
  currencyCode,
  items,
  purchaseDate,
}

class ExtractedInvoicePatch
    extends PatchBase<ExtractedInvoice, ExtractedInvoice$> {
  ExtractedInvoice applyTo(ExtractedInvoice entity) {
    return entity.patchWithExtractedInvoice(this);
  }

  ExtractedInvoicePatch withId(String? value) {
    patchMap[ExtractedInvoice$.id] = value;
    return this;
  }

  ExtractedInvoicePatch withStoreName(String? value) {
    patchMap[ExtractedInvoice$.storeName] = value;
    return this;
  }

  ExtractedInvoicePatch withTotal(double? value) {
    patchMap[ExtractedInvoice$.total] = value;
    return this;
  }

  ExtractedInvoicePatch withCurrencyCode(String? value) {
    patchMap[ExtractedInvoice$.currencyCode] = value;
    return this;
  }

  ExtractedInvoicePatch withItems(List<String>? value) {
    patchMap[ExtractedInvoice$.items] = value;
    return this;
  }

  ExtractedInvoicePatch withPurchaseDate(DateTime? value) {
    patchMap[ExtractedInvoice$.purchaseDate] = value;
    return this;
  }
}

/// Field descriptors for [ExtractedInvoice] query construction
abstract final class ExtractedInvoiceFields {
  static const id = Field<ExtractedInvoice, String?>('id', _$id);

  static const storeName = Field<ExtractedInvoice, String?>(
    'storeName',
    _$storeName,
  );

  static const total = Field<ExtractedInvoice, double?>('total', _$total);

  static const currencyCode = Field<ExtractedInvoice, String?>(
    'currencyCode',
    _$currencyCode,
  );

  static const items = Field<ExtractedInvoice, List<String>?>('items', _$items);

  static const purchaseDate = Field<ExtractedInvoice, DateTime?>(
    'purchaseDate',
    _$purchaseDate,
  );

  static String? _$id(ExtractedInvoice e) {
    return e.id;
  }

  static String? _$storeName(ExtractedInvoice e) {
    return e.storeName;
  }

  static double? _$total(ExtractedInvoice e) {
    return e.total;
  }

  static String? _$currencyCode(ExtractedInvoice e) {
    return e.currencyCode;
  }

  static List<String>? _$items(ExtractedInvoice e) {
    return e.items;
  }

  static DateTime? _$purchaseDate(ExtractedInvoice e) {
    return e.purchaseDate;
  }
}

extension ExtractedInvoiceCompareE on ExtractedInvoice {
  Map<String, dynamic> compareToExtractedInvoice(ExtractedInvoice other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (storeName != other.storeName) {
      diff['storeName'] = () => other.storeName;
    }

    if (total != other.total) {
      diff['total'] = () => other.total;
    }

    if (currencyCode != other.currencyCode) {
      diff['currencyCode'] = () => other.currencyCode;
    }

    if (items != other.items) {
      diff['items'] = () => other.items;
    }

    if (purchaseDate != other.purchaseDate) {
      diff['purchaseDate'] = () => other.purchaseDate;
    }
    return diff;
  }
}
