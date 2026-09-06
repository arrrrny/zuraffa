// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_check_invoice/price_check_invoice.dart';

abstract class PriceCheckInvoiceDataSource with Loggable, FailureHandler {
  Future<PriceCheckInvoice> get(QueryParams<PriceCheckInvoice> params);
  Future<PriceCheckInvoice> update(
    UpdateParams<String, PriceCheckInvoicePatch> params,
  );
  Future<PriceCheckInvoice> toggle(
    ToggleParams<String, Field<PriceCheckInvoice, dynamic>> params,
  );
}

// END GENERATED
