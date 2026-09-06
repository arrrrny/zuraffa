// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/extracted_invoice/extracted_invoice.dart';
import 'extracted_invoice_presenter.dart';

class ExtractedInvoiceController extends Controller {
  ExtractedInvoiceController(this._presenter);

  final ExtractedInvoicePresenter _presenter;

  Future<void> getExtractedInvoice(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getExtractedInvoice(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateExtractedInvoice(
    String id,
    ExtractedInvoicePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateExtractedInvoice(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleExtractedInvoice(
    String id,
    Field<ExtractedInvoice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleExtractedInvoice(
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
