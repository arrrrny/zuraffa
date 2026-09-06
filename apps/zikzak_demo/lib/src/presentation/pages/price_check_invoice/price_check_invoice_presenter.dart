// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/price_check_invoice/price_check_invoice.dart';
import '../../../domain/usecases/price_check_invoice/get_price_check_invoice_usecase.dart';
import '../../../domain/usecases/price_check_invoice/toggle_price_check_invoice_usecase.dart';
import '../../../domain/usecases/price_check_invoice/update_price_check_invoice_usecase.dart';

class PriceCheckInvoicePresenter extends Presenter {
  PriceCheckInvoicePresenter() {
    _getPriceCheckInvoice = registerUseCase(
      getIt<GetPriceCheckInvoiceUseCase>(),
    );
    _updatePriceCheckInvoice = registerUseCase(
      getIt<UpdatePriceCheckInvoiceUseCase>(),
    );
    _togglePriceCheckInvoice = registerUseCase(
      getIt<TogglePriceCheckInvoiceUseCase>(),
    );
  }

  late final GetPriceCheckInvoiceUseCase _getPriceCheckInvoice;

  late final UpdatePriceCheckInvoiceUseCase _updatePriceCheckInvoice;

  late final TogglePriceCheckInvoiceUseCase _togglePriceCheckInvoice;

  Future<Result<PriceCheckInvoice, AppFailure>> getPriceCheckInvoice(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getPriceCheckInvoice.call(
      QueryParams<PriceCheckInvoice>(
        filter: Eq(PriceCheckInvoiceFields.id, id),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceCheckInvoice, AppFailure>> updatePriceCheckInvoice(
    String id,
    PriceCheckInvoicePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updatePriceCheckInvoice.call(
      UpdateParams<String, PriceCheckInvoicePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceCheckInvoice, AppFailure>> togglePriceCheckInvoice(
    String id,
    Field<PriceCheckInvoice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _togglePriceCheckInvoice.call(
      ToggleParams<String, Field<PriceCheckInvoice, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
