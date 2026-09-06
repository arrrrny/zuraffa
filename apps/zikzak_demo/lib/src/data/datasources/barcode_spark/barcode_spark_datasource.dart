// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode_spark/barcode_spark.dart';

abstract class BarcodeSparkDataSource with Loggable, FailureHandler {
  Future<BarcodeSpark> get(QueryParams<BarcodeSpark> params);
  Future<BarcodeSpark> update(UpdateParams<String, BarcodeSparkPatch> params);
  Future<BarcodeSpark> toggle(
    ToggleParams<String, Field<BarcodeSpark, dynamic>> params,
  );
}

// END GENERATED
