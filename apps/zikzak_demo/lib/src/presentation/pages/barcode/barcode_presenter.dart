// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/barcode/barcode.dart';
import '../../../domain/usecases/barcode/get_barcode_usecase.dart';
import '../../../domain/usecases/barcode/toggle_barcode_usecase.dart';
import '../../../domain/usecases/barcode/update_barcode_usecase.dart';

class BarcodePresenter extends Presenter {
  BarcodePresenter() {
    _getBarcode = registerUseCase(getIt<GetBarcodeUseCase>());
    _updateBarcode = registerUseCase(getIt<UpdateBarcodeUseCase>());
    _toggleBarcode = registerUseCase(getIt<ToggleBarcodeUseCase>());
  }

  late final GetBarcodeUseCase _getBarcode;

  late final UpdateBarcodeUseCase _updateBarcode;

  late final ToggleBarcodeUseCase _toggleBarcode;

  Future<Result<Barcode, AppFailure>> getBarcode(
    String value, [
    CancelToken? cancelToken,
  ]) {
    return _getBarcode.call(
      QueryParams<Barcode>(filter: Eq(BarcodeFields.value, value)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Barcode, AppFailure>> updateBarcode(
    String value,
    BarcodePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateBarcode.call(
      UpdateParams<String, BarcodePatch>(id: value, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Barcode, AppFailure>> toggleBarcode(
    String value,
    Field<Barcode, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleBarcode.call(
      ToggleParams<String, Field<Barcode, dynamic>>(
        id: value,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
