// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/barcode/barcode.dart';
import 'barcode_presenter.dart';

class BarcodeController extends Controller {
  BarcodeController(this._presenter);

  final BarcodePresenter _presenter;

  Future<void> getBarcode(String value, [CancelToken? cancelToken]) async {
    final result = await _presenter.getBarcode(value, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateBarcode(
    String value,
    BarcodePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateBarcode(value, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleBarcode(
    String value,
    Field<Barcode, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleBarcode(
      value,
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
