// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/category/category.dart';

abstract class CategoryDataSource with Loggable, FailureHandler {
  Future<Category> get(QueryParams<Category> params);
  Future<Category> update(UpdateParams<String, CategoryPatch> params);
  Future<Category> toggle(
    ToggleParams<String, Field<Category, dynamic>> params,
  );
}

// END GENERATED
