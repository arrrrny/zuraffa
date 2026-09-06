// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/extracted_invoice/extracted_invoice.dart';
import 'extracted_invoice_datasource.dart';

class ExtractedInvoiceRemoteDataSource
    with Loggable, FailureHandler
    implements ExtractedInvoiceDataSource {
  @override
  Future<ExtractedInvoice> get(QueryParams<ExtractedInvoice> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ExtractedInvoice> update(
    UpdateParams<String, ExtractedInvoicePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ExtractedInvoice> toggle(
    ToggleParams<String, Field<ExtractedInvoice, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
