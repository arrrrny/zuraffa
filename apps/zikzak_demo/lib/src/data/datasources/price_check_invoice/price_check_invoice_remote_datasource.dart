// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_check_invoice/price_check_invoice.dart';
import 'price_check_invoice_datasource.dart';

class PriceCheckInvoiceRemoteDataSource
    with Loggable, FailureHandler
    implements PriceCheckInvoiceDataSource {
  @override
  Future<PriceCheckInvoice> get(QueryParams<PriceCheckInvoice> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<PriceCheckInvoice> update(
    UpdateParams<String, PriceCheckInvoicePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<PriceCheckInvoice> toggle(
    ToggleParams<String, Field<PriceCheckInvoice, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
