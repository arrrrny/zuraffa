// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/barcode_spark/barcode_spark.dart';
import 'barcode_spark_presenter.dart';

class BarcodeSparkController extends Controller {
  BarcodeSparkController(this._presenter);

  final BarcodeSparkPresenter _presenter;

  Future<void> getBarcodeSpark(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getBarcodeSpark(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateBarcodeSpark(
    String id,
    BarcodeSparkPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateBarcodeSpark(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleBarcodeSpark(
    String id,
    Field<BarcodeSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleBarcodeSpark(
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
