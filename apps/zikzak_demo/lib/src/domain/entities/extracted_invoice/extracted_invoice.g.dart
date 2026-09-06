// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extracted_invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExtractedInvoice _$ExtractedInvoiceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExtractedInvoice', json, ($checkedConvert) {
      final val = ExtractedInvoice(
        id: $checkedConvert('id', (v) => v as String?),
        storeName: $checkedConvert('storeName', (v) => v as String?),
        total: $checkedConvert('total', (v) => (v as num?)?.toDouble()),
        currencyCode: $checkedConvert('currencyCode', (v) => v as String?),
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
        ),
        purchaseDate: $checkedConvert(
          'purchaseDate',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExtractedInvoiceToJson(ExtractedInvoice instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'storeName': ?instance.storeName,
      'total': ?instance.total,
      'currencyCode': ?instance.currencyCode,
      'items': ?instance.items,
      'purchaseDate': ?instance.purchaseDate?.toIso8601String(),
    };
