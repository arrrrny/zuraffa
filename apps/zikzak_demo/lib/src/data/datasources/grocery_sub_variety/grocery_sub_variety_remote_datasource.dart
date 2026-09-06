// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_sub_variety/grocery_sub_variety.dart';
import 'grocery_sub_variety_datasource.dart';

class GrocerySubVarietyRemoteDataSource
    with Loggable, FailureHandler
    implements GrocerySubVarietyDataSource {
  @override
  Future<GrocerySubVariety> get(QueryParams<GrocerySubVariety> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GrocerySubVariety> update(
    UpdateParams<String, GrocerySubVarietyPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GrocerySubVariety> toggle(
    ToggleParams<String, Field<GrocerySubVariety, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
