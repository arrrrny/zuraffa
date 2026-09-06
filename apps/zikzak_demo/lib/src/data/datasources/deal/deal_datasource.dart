// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/deal/deal.dart';

abstract class DealDataSource with Loggable, FailureHandler {
  Future<Deal> get(QueryParams<Deal> params);
  Future<Deal> update(UpdateParams<String, DealPatch> params);
  Future<Deal> toggle(ToggleParams<String, Field<Deal, dynamic>> params);
}

// END GENERATED
