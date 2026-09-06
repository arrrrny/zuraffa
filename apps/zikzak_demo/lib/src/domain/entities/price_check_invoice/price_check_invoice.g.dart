// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_check_invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceCheckInvoice _$PriceCheckInvoiceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PriceCheckInvoice', json, ($checkedConvert) {
      final val = PriceCheckInvoice(
        id: $checkedConvert('id', (v) => v as String),
        barcode: $checkedConvert('barcode', (v) => v as String?),
        productName: $checkedConvert('productName', (v) => v as String?),
        storeName: $checkedConvert('storeName', (v) => v as String?),
        price: $checkedConvert('price', (v) => (v as num?)?.toDouble()),
        unit: $checkedConvert('unit', (v) => v as String?),
        quantity: $checkedConvert('quantity', (v) => (v as num?)?.toDouble()),
        purchaseDate: $checkedConvert(
          'purchaseDate',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        extracted: $checkedConvert(
          'extracted',
          (v) => v == null
              ? null
              : ExtractedInvoice.fromJson(v as Map<String, dynamic>),
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PriceCheckInvoiceToJson(PriceCheckInvoice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'barcode': ?instance.barcode,
      'productName': ?instance.productName,
      'storeName': ?instance.storeName,
      'price': ?instance.price,
      'unit': ?instance.unit,
      'quantity': ?instance.quantity,
      'purchaseDate': ?instance.purchaseDate?.toIso8601String(),
      'extracted': ?instance.extracted?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
