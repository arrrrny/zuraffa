// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode/barcode.dart';
import 'barcode_datasource.dart';

class BarcodeRemoteDataSource
    with Loggable, FailureHandler
    implements BarcodeDataSource {
  @override
  Future<Barcode> get(QueryParams<Barcode> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Barcode> update(UpdateParams<String, BarcodePatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Barcode> toggle(
    ToggleParams<String, Field<Barcode, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
