// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_sub_variety/grocery_sub_variety.dart';

abstract class GrocerySubVarietyDataSource with Loggable, FailureHandler {
  Future<GrocerySubVariety> get(QueryParams<GrocerySubVariety> params);
  Future<GrocerySubVariety> update(
    UpdateParams<String, GrocerySubVarietyPatch> params,
  );
  Future<GrocerySubVariety> toggle(
    ToggleParams<String, Field<GrocerySubVariety, dynamic>> params,
  );
}

// END GENERATED
