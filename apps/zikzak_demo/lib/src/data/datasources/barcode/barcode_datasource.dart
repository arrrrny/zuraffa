// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode/barcode.dart';

abstract class BarcodeDataSource with Loggable, FailureHandler {
  Future<Barcode> get(QueryParams<Barcode> params);
  Future<Barcode> update(UpdateParams<String, BarcodePatch> params);
  Future<Barcode> toggle(ToggleParams<String, Field<Barcode, dynamic>> params);
}

// END GENERATED
