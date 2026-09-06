// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/extracted_invoice/extracted_invoice.dart';

abstract class ExtractedInvoiceDataSource with Loggable, FailureHandler {
  Future<ExtractedInvoice> get(QueryParams<ExtractedInvoice> params);
  Future<ExtractedInvoice> update(
    UpdateParams<String, ExtractedInvoicePatch> params,
  );
  Future<ExtractedInvoice> toggle(
    ToggleParams<String, Field<ExtractedInvoice, dynamic>> params,
  );
}

// END GENERATED
