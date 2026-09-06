// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/barcode_spark/barcode_spark.dart';
import '../../../domain/usecases/barcode_spark/get_barcode_spark_usecase.dart';
import '../../../domain/usecases/barcode_spark/toggle_barcode_spark_usecase.dart';
import '../../../domain/usecases/barcode_spark/update_barcode_spark_usecase.dart';

class BarcodeSparkPresenter extends Presenter {
  BarcodeSparkPresenter() {
    _getBarcodeSpark = registerUseCase(getIt<GetBarcodeSparkUseCase>());
    _updateBarcodeSpark = registerUseCase(getIt<UpdateBarcodeSparkUseCase>());
    _toggleBarcodeSpark = registerUseCase(getIt<ToggleBarcodeSparkUseCase>());
  }

  late final GetBarcodeSparkUseCase _getBarcodeSpark;

  late final UpdateBarcodeSparkUseCase _updateBarcodeSpark;

  late final ToggleBarcodeSparkUseCase _toggleBarcodeSpark;

  Future<Result<BarcodeSpark, AppFailure>> getBarcodeSpark(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getBarcodeSpark.call(
      QueryParams<BarcodeSpark>(filter: Eq(BarcodeSparkFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<BarcodeSpark, AppFailure>> updateBarcodeSpark(
    String id,
    BarcodeSparkPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateBarcodeSpark.call(
      UpdateParams<String, BarcodeSparkPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<BarcodeSpark, AppFailure>> toggleBarcodeSpark(
    String id,
    Field<BarcodeSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleBarcodeSpark.call(
      ToggleParams<String, Field<BarcodeSpark, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
