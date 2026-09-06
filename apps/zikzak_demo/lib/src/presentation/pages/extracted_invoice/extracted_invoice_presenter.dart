// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/extracted_invoice/extracted_invoice.dart';
import '../../../domain/usecases/extracted_invoice/get_extracted_invoice_usecase.dart';
import '../../../domain/usecases/extracted_invoice/toggle_extracted_invoice_usecase.dart';
import '../../../domain/usecases/extracted_invoice/update_extracted_invoice_usecase.dart';

class ExtractedInvoicePresenter extends Presenter {
  ExtractedInvoicePresenter() {
    _getExtractedInvoice = registerUseCase(getIt<GetExtractedInvoiceUseCase>());
    _updateExtractedInvoice = registerUseCase(
      getIt<UpdateExtractedInvoiceUseCase>(),
    );
    _toggleExtractedInvoice = registerUseCase(
      getIt<ToggleExtractedInvoiceUseCase>(),
    );
  }

  late final GetExtractedInvoiceUseCase _getExtractedInvoice;

  late final UpdateExtractedInvoiceUseCase _updateExtractedInvoice;

  late final ToggleExtractedInvoiceUseCase _toggleExtractedInvoice;

  Future<Result<ExtractedInvoice, AppFailure>> getExtractedInvoice(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getExtractedInvoice.call(
      QueryParams<ExtractedInvoice>(filter: Eq(ExtractedInvoiceFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ExtractedInvoice, AppFailure>> updateExtractedInvoice(
    String id,
    ExtractedInvoicePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateExtractedInvoice.call(
      UpdateParams<String, ExtractedInvoicePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ExtractedInvoice, AppFailure>> toggleExtractedInvoice(
    String id,
    Field<ExtractedInvoice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleExtractedInvoice.call(
      ToggleParams<String, Field<ExtractedInvoice, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
