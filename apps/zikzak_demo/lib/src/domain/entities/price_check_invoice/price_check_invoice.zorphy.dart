// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'price_check_invoice.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class PriceCheckInvoice {
  PriceCheckInvoice({
    required String this.id,
    String? this.barcode,
    String? this.productName,
    String? this.storeName,
    double? this.price,
    String? this.unit,
    double? this.quantity,
    DateTime? this.purchaseDate,
    ExtractedInvoice? this.extracted,
    required DateTime this.createdAt,
  });

  factory PriceCheckInvoice.fromJson(Map<String, dynamic> json) =>
      _$PriceCheckInvoiceFromJson(json);

  final String id;

  final String? barcode;

  final String? productName;

  final String? storeName;

  final double? price;

  final String? unit;

  final double? quantity;

  final DateTime? purchaseDate;

  final ExtractedInvoice? extracted;

  final DateTime createdAt;

  PriceCheckInvoice copyWith({
    String? id,
    String? barcode,
    String? productName,
    String? storeName,
    double? price,
    String? unit,
    double? quantity,
    DateTime? purchaseDate,
    ExtractedInvoice? extracted,
    DateTime? createdAt,
  }) {
    return PriceCheckInvoice(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      storeName: storeName ?? this.storeName,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      extracted: extracted ?? this.extracted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  PriceCheckInvoice copyWithField<T>(
    Field<PriceCheckInvoice, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'barcode':
        return copyWith(barcode: value as String?);
      case 'productName':
        return copyWith(productName: value as String?);
      case 'storeName':
        return copyWith(storeName: value as String?);
      case 'price':
        return copyWith(price: value as double?);
      case 'unit':
        return copyWith(unit: value as String?);
      case 'quantity':
        return copyWith(quantity: value as double?);
      case 'purchaseDate':
        return copyWith(purchaseDate: value as DateTime?);
      case 'extracted':
        return copyWith(extracted: value as ExtractedInvoice?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'PriceCheckInvoice has no settable field with this name',
        );
    }
  }

  PriceCheckInvoice copyWithPriceCheckInvoice({
    String? id,
    String? barcode,
    String? productName,
    String? storeName,
    double? price,
    String? unit,
    double? quantity,
    DateTime? purchaseDate,
    ExtractedInvoice? extracted,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      barcode: barcode,
      productName: productName,
      storeName: storeName,
      price: price,
      unit: unit,
      quantity: quantity,
      purchaseDate: purchaseDate,
      extracted: extracted,
      createdAt: createdAt,
    );
  }

  PriceCheckInvoice patchWithPriceCheckInvoice([
    PriceCheckInvoicePatch? patchInput,
  ]) {
    final _patcher = patchInput ?? PriceCheckInvoicePatch();
    final _patchMap = _patcher.patchMap;
    return PriceCheckInvoice(
      id: _patchMap.containsKey(PriceCheckInvoice$.id)
          ? ((_patchMap[PriceCheckInvoice$.id] is Function)
                    ? _patchMap[PriceCheckInvoice$.id](this.id)
                    : (_patchMap[PriceCheckInvoice$.id] is Patch)
                    ? _patchMap[PriceCheckInvoice$.id].applyTo(this.id)
                    : _patchMap[PriceCheckInvoice$.id])
                as String
          : this.id,
      barcode: _patchMap.containsKey(PriceCheckInvoice$.barcode)
          ? ((_patchMap[PriceCheckInvoice$.barcode] is Function)
                    ? _patchMap[PriceCheckInvoice$.barcode](this.barcode)
                    : (_patchMap[PriceCheckInvoice$.barcode] is Patch)
                    ? _patchMap[PriceCheckInvoice$.barcode].applyTo(
                        this.barcode,
                      )
                    : _patchMap[PriceCheckInvoice$.barcode])
                as String?
          : this.barcode,
      productName: _patchMap.containsKey(PriceCheckInvoice$.productName)
          ? ((_patchMap[PriceCheckInvoice$.productName] is Function)
                    ? _patchMap[PriceCheckInvoice$.productName](
                        this.productName,
                      )
                    : (_patchMap[PriceCheckInvoice$.productName] is Patch)
                    ? _patchMap[PriceCheckInvoice$.productName].applyTo(
                        this.productName,
                      )
                    : _patchMap[PriceCheckInvoice$.productName])
                as String?
          : this.productName,
      storeName: _patchMap.containsKey(PriceCheckInvoice$.storeName)
          ? ((_patchMap[PriceCheckInvoice$.storeName] is Function)
                    ? _patchMap[PriceCheckInvoice$.storeName](this.storeName)
                    : (_patchMap[PriceCheckInvoice$.storeName] is Patch)
                    ? _patchMap[PriceCheckInvoice$.storeName].applyTo(
                        this.storeName,
                      )
                    : _patchMap[PriceCheckInvoice$.storeName])
                as String?
          : this.storeName,
      price: _patchMap.containsKey(PriceCheckInvoice$.price)
          ? ((_patchMap[PriceCheckInvoice$.price] is Function)
                    ? _patchMap[PriceCheckInvoice$.price](this.price)
                    : (_patchMap[PriceCheckInvoice$.price] is Patch)
                    ? _patchMap[PriceCheckInvoice$.price].applyTo(this.price)
                    : _patchMap[PriceCheckInvoice$.price])
                as double?
          : this.price,
      unit: _patchMap.containsKey(PriceCheckInvoice$.unit)
          ? ((_patchMap[PriceCheckInvoice$.unit] is Function)
                    ? _patchMap[PriceCheckInvoice$.unit](this.unit)
                    : (_patchMap[PriceCheckInvoice$.unit] is Patch)
                    ? _patchMap[PriceCheckInvoice$.unit].applyTo(this.unit)
                    : _patchMap[PriceCheckInvoice$.unit])
                as String?
          : this.unit,
      quantity: _patchMap.containsKey(PriceCheckInvoice$.quantity)
          ? ((_patchMap[PriceCheckInvoice$.quantity] is Function)
                    ? _patchMap[PriceCheckInvoice$.quantity](this.quantity)
                    : (_patchMap[PriceCheckInvoice$.quantity] is Patch)
                    ? _patchMap[PriceCheckInvoice$.quantity].applyTo(
                        this.quantity,
                      )
                    : _patchMap[PriceCheckInvoice$.quantity])
                as double?
          : this.quantity,
      purchaseDate: _patchMap.containsKey(PriceCheckInvoice$.purchaseDate)
          ? ((_patchMap[PriceCheckInvoice$.purchaseDate] is Function)
                    ? _patchMap[PriceCheckInvoice$.purchaseDate](
                        this.purchaseDate,
                      )
                    : (_patchMap[PriceCheckInvoice$.purchaseDate] is Patch)
                    ? _patchMap[PriceCheckInvoice$.purchaseDate].applyTo(
                        this.purchaseDate,
                      )
                    : _patchMap[PriceCheckInvoice$.purchaseDate])
                as DateTime?
          : this.purchaseDate,
      extracted: _patchMap.containsKey(PriceCheckInvoice$.extracted)
          ? ((_patchMap[PriceCheckInvoice$.extracted] is Function)
                    ? _patchMap[PriceCheckInvoice$.extracted](this.extracted)
                    : (_patchMap[PriceCheckInvoice$.extracted] is Patch)
                    ? _patchMap[PriceCheckInvoice$.extracted].applyTo(
                        this.extracted,
                      )
                    : _patchMap[PriceCheckInvoice$.extracted])
                as ExtractedInvoice?
          : this.extracted,
      createdAt: _patchMap.containsKey(PriceCheckInvoice$.createdAt)
          ? ((_patchMap[PriceCheckInvoice$.createdAt] is Function)
                    ? _patchMap[PriceCheckInvoice$.createdAt](this.createdAt)
                    : (_patchMap[PriceCheckInvoice$.createdAt] is Patch)
                    ? _patchMap[PriceCheckInvoice$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[PriceCheckInvoice$.createdAt])
                as DateTime
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PriceCheckInvoice &&
        id == other.id &&
        barcode == other.barcode &&
        productName == other.productName &&
        storeName == other.storeName &&
        price == other.price &&
        unit == other.unit &&
        quantity == other.quantity &&
        purchaseDate == other.purchaseDate &&
        extracted == other.extracted &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.barcode,
      this.productName,
      this.storeName,
      this.price,
      this.unit,
      this.quantity,
      this.purchaseDate,
      this.extracted,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'PriceCheckInvoice(' +
        'id: ${id}' +
        ', ' +
        'barcode: ${barcode}' +
        ', ' +
        'productName: ${productName}' +
        ', ' +
        'storeName: ${storeName}' +
        ', ' +
        'price: ${price}' +
        ', ' +
        'unit: ${unit}' +
        ', ' +
        'quantity: ${quantity}' +
        ', ' +
        'purchaseDate: ${purchaseDate}' +
        ', ' +
        'extracted: ${extracted}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$PriceCheckInvoiceToJson(this);
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

extension PriceCheckInvoicePropertyHelpers on PriceCheckInvoice {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasBarcode {
    return this.barcode?.isNotEmpty == true;
  }

  bool get noBarcode {
    return this.barcode?.isEmpty ?? true;
  }

  String get barcodeRequired {
    return this.barcode ??
        (throw StateError('barcode is required but was null'));
  }

  bool get hasProductName {
    return this.productName?.isNotEmpty == true;
  }

  bool get noProductName {
    return this.productName?.isEmpty ?? true;
  }

  String get productNameRequired {
    return this.productName ??
        (throw StateError('productName is required but was null'));
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

  bool get hasPrice {
    return this.price != null;
  }

  bool get noPrice {
    return this.price == null;
  }

  double get priceRequired {
    return this.price ?? (throw StateError('price is required but was null'));
  }

  bool get hasUnit {
    return this.unit?.isNotEmpty == true;
  }

  bool get noUnit {
    return this.unit?.isEmpty ?? true;
  }

  String get unitRequired {
    return this.unit ?? (throw StateError('unit is required but was null'));
  }

  bool get hasQuantity {
    return this.quantity != null;
  }

  bool get noQuantity {
    return this.quantity == null;
  }

  double get quantityRequired {
    return this.quantity ??
        (throw StateError('quantity is required but was null'));
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

  bool get hasExtracted {
    return this.extracted != null;
  }

  bool get noExtracted {
    return this.extracted == null;
  }

  ExtractedInvoice get extractedRequired {
    return this.extracted ??
        (throw StateError('extracted is required but was null'));
  }
}

extension PriceCheckInvoiceSerialization on PriceCheckInvoice {
  Map<String, dynamic> toJson() {
    return _$PriceCheckInvoiceToJson(this);
  }
}

enum PriceCheckInvoice$ {
  id,
  barcode,
  productName,
  storeName,
  price,
  unit,
  quantity,
  purchaseDate,
  extracted,
  createdAt,
}

class PriceCheckInvoicePatch
    extends PatchBase<PriceCheckInvoice, PriceCheckInvoice$> {
  PriceCheckInvoice applyTo(PriceCheckInvoice entity) {
    return entity.patchWithPriceCheckInvoice(this);
  }

  PriceCheckInvoicePatch withId(String? value) {
    patchMap[PriceCheckInvoice$.id] = value;
    return this;
  }

  PriceCheckInvoicePatch withBarcode(String? value) {
    patchMap[PriceCheckInvoice$.barcode] = value;
    return this;
  }

  PriceCheckInvoicePatch withProductName(String? value) {
    patchMap[PriceCheckInvoice$.productName] = value;
    return this;
  }

  PriceCheckInvoicePatch withStoreName(String? value) {
    patchMap[PriceCheckInvoice$.storeName] = value;
    return this;
  }

  PriceCheckInvoicePatch withPrice(double? value) {
    patchMap[PriceCheckInvoice$.price] = value;
    return this;
  }

  PriceCheckInvoicePatch withUnit(String? value) {
    patchMap[PriceCheckInvoice$.unit] = value;
    return this;
  }

  PriceCheckInvoicePatch withQuantity(double? value) {
    patchMap[PriceCheckInvoice$.quantity] = value;
    return this;
  }

  PriceCheckInvoicePatch withPurchaseDate(DateTime? value) {
    patchMap[PriceCheckInvoice$.purchaseDate] = value;
    return this;
  }

  PriceCheckInvoicePatch withExtracted(ExtractedInvoice? value) {
    patchMap[PriceCheckInvoice$.extracted] = value;
    return this;
  }

  PriceCheckInvoicePatch withExtractedPatch(ExtractedInvoicePatch patch) {
    patchMap[PriceCheckInvoice$.extracted] = patch;
    return this;
  }

  PriceCheckInvoicePatch withExtractedPatchFunc(
    ExtractedInvoicePatch Function(ExtractedInvoicePatch) patch,
  ) {
    patchMap[PriceCheckInvoice$.extracted] = (dynamic current) {
      var currentPatch = ExtractedInvoicePatch();
      return patch(currentPatch).applyTo(current as ExtractedInvoice);
    };
    return this;
  }

  PriceCheckInvoicePatch withCreatedAt(DateTime? value) {
    patchMap[PriceCheckInvoice$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [PriceCheckInvoice] query construction
abstract final class PriceCheckInvoiceFields {
  static const id = Field<PriceCheckInvoice, String>('id', _$id);

  static const barcode = Field<PriceCheckInvoice, String?>(
    'barcode',
    _$barcode,
  );

  static const productName = Field<PriceCheckInvoice, String?>(
    'productName',
    _$productName,
  );

  static const storeName = Field<PriceCheckInvoice, String?>(
    'storeName',
    _$storeName,
  );

  static const price = Field<PriceCheckInvoice, double?>('price', _$price);

  static const unit = Field<PriceCheckInvoice, String?>('unit', _$unit);

  static const quantity = Field<PriceCheckInvoice, double?>(
    'quantity',
    _$quantity,
  );

  static const purchaseDate = Field<PriceCheckInvoice, DateTime?>(
    'purchaseDate',
    _$purchaseDate,
  );

  static const extracted = Field<PriceCheckInvoice, ExtractedInvoice?>(
    'extracted',
    _$extracted,
  );

  static const createdAt = Field<PriceCheckInvoice, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static String _$id(PriceCheckInvoice e) {
    return e.id;
  }

  static String? _$barcode(PriceCheckInvoice e) {
    return e.barcode;
  }

  static String? _$productName(PriceCheckInvoice e) {
    return e.productName;
  }

  static String? _$storeName(PriceCheckInvoice e) {
    return e.storeName;
  }

  static double? _$price(PriceCheckInvoice e) {
    return e.price;
  }

  static String? _$unit(PriceCheckInvoice e) {
    return e.unit;
  }

  static double? _$quantity(PriceCheckInvoice e) {
    return e.quantity;
  }

  static DateTime? _$purchaseDate(PriceCheckInvoice e) {
    return e.purchaseDate;
  }

  static ExtractedInvoice? _$extracted(PriceCheckInvoice e) {
    return e.extracted;
  }

  static DateTime _$createdAt(PriceCheckInvoice e) {
    return e.createdAt;
  }
}

extension PriceCheckInvoiceCompareE on PriceCheckInvoice {
  Map<String, dynamic> compareToPriceCheckInvoice(PriceCheckInvoice other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (barcode != other.barcode) {
      diff['barcode'] = () => other.barcode;
    }

    if (productName != other.productName) {
      diff['productName'] = () => other.productName;
    }

    if (storeName != other.storeName) {
      diff['storeName'] = () => other.storeName;
    }

    if (price != other.price) {
      diff['price'] = () => other.price;
    }

    if (unit != other.unit) {
      diff['unit'] = () => other.unit;
    }

    if (quantity != other.quantity) {
      diff['quantity'] = () => other.quantity;
    }

    if (purchaseDate != other.purchaseDate) {
      diff['purchaseDate'] = () => other.purchaseDate;
    }

    if (extracted != other.extracted) {
      diff['extracted'] = () => other.extracted;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
