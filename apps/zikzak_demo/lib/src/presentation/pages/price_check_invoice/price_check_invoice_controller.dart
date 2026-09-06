// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/price_check_invoice/price_check_invoice.dart';
import 'price_check_invoice_presenter.dart';

class PriceCheckInvoiceController extends Controller {
  PriceCheckInvoiceController(this._presenter);

  final PriceCheckInvoicePresenter _presenter;

  Future<void> getPriceCheckInvoice(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getPriceCheckInvoice(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updatePriceCheckInvoice(
    String id,
    PriceCheckInvoicePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updatePriceCheckInvoice(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> togglePriceCheckInvoice(
    String id,
    Field<PriceCheckInvoice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.togglePriceCheckInvoice(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
