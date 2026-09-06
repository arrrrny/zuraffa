// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode_spark/barcode_spark.dart';
import 'barcode_spark_datasource.dart';

class BarcodeSparkRemoteDataSource
    with Loggable, FailureHandler
    implements BarcodeSparkDataSource {
  @override
  Future<BarcodeSpark> get(QueryParams<BarcodeSpark> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<BarcodeSpark> update(
    UpdateParams<String, BarcodeSparkPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<BarcodeSpark> toggle(
    ToggleParams<String, Field<BarcodeSpark, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
